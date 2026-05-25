terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }

  backend "s3" {
    bucket         = "dgsn-tf-state-prod"
    key            = "terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "dgsn-tf-locks-prod"
    encrypt        = true
    versioning     = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "DGSN"
      Compliance  = "NIST-SP-800-186"
    }
  }
}

provider "kubernetes" {
  host                   = module.aws.cluster_endpoint
  cluster_ca_certificate = base64decode(module.aws.cluster_ca_certificate)
  token                  = module.aws.cluster_token
}

provider "helm" {
  kubernetes {
    host                   = module.aws.cluster_endpoint
    cluster_ca_certificate = base64decode(module.aws.cluster_ca_certificate)
    token                  = module.aws.cluster_token
  }
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "prod"
}

variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-west-2"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
  default     = "dgsn-prod"
}

variable "instance_types" {
  type        = list(string)
  description = "EC2 instance types for worker nodes"
  default     = ["m5.xlarge", "m5a.xlarge", "m6i.xlarge"]
}

variable "min_size" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 5
}

variable "max_size" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 20
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
  default     = "10.2.0.0/16"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnet CIDRs (multi-AZ)"
  default     = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnet CIDRs (multi-AZ)"
  default     = ["10.2.101.0/24", "10.2.102.0/24", "10.2.103.0/24"]
}

variable "pqc_enabled" {
  type        = bool
  description = "Enable Post-Quantum Cryptography (NIST compliant)"
  default     = true
}

variable "enable_high_availability" {
  type        = bool
  description = "Enable high availability features"
  default     = true
}

variable "enable_monitoring" {
  type        = bool
  description = "Enable full monitoring stack"
  default     = true
}

module "aws" {
  source = "../../modules/aws"

  environment    = var.environment
  cluster_name   = var.cluster_name
  instance_types = var.instance_types
  min_size       = var.min_size
  max_size       = var.max_size
  region         = var.region
  vpc_cidr       = var.vpc_cidr
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  pqc_enabled    = var.pqc_enabled

  multi_az           = var.enable_high_availability
  use_spot_instances = false
  enable_vpc_flow_logs = true
  enable_cloudwatch  = true
}

resource "kubernetes_namespace" "dgsn" {
  metadata {
    name = "dgsn-prod"

    labels = {
      name = "dgsn-prod"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"

    labels = {
      name = "monitoring"
    }
  }
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"

    labels = {
      name = "cert-manager"
    }
  }
}

module "infra" {
  source = "../../../helm/dgsn-infra"

  depends_on = [
    kubernetes_namespace.dgsn,
    kubernetes_namespace.monitoring,
    kubernetes_namespace.cert_manager,
  ]
}

module "backend" {
  source = "../../../helm/dgsn-backend"

  namespace = kubernetes_namespace.dgsn.metadata[0].name

  values = [
    yamlencode({
      autoscaling = {
        enabled = true
        minReplicas = 5
        maxReplicas = 15
        targetCPUUtilizationPercentage = 70
      }
      resources = {
        requests = {
          cpu = "1000m"
          memory = "1Gi"
        }
        limits = {
          cpu = "4000m"
          memory = "4Gi"
        }
      }
    })
  ]

  depends_on = [
    module.infra,
  ]
}

module "crypto" {
  source = "../../../helm/dgsn-crypto"

  namespace = kubernetes_namespace.dgsn.metadata[0].name

  values = [
    yamlencode({
      pqc = {
        enabled = var.pqc_enabled
        defaultAlgorithm = "CRYSTALS-KYBER-1024"
        securityLevel = 5
      }
      tls = {
        enabled = true
        pqcEnabled = var.pqc_enabled
      }
      autoscaling = {
        enabled = true
        minReplicas = 3
        maxReplicas = 10
      }
    })
  ]

  depends_on = [
    module.infra,
  ]
}

module "quantum" {
  source = "../../../helm/dgsn-quantum"

  namespace = kubernetes_namespace.dgsn.metadata[0].name

  values = [
    yamlencode({
      autoscaling = {
        enabled = true
        minReplicas = 2
        maxReplicas = 8
      }
      quantum = {
        enableQPU = false
      }
    })
  ]

  depends_on = [
    module.infra,
  ]
}

module "signal" {
  source = "../../../helm/dgsn-signal"

  namespace = kubernetes_namespace.dgsn.metadata[0].name

  values = [
    yamlencode({
      autoscaling = {
        enabled = true
        minReplicas = 3
        maxReplicas = 10
      }
    })
  ]

  depends_on = [
    module.infra,
  ]
}

module "frontend" {
  source = "../../../helm/dgsn-frontend"

  namespace = kubernetes_namespace.dgsn.metadata[0].name

  values = [
    yamlencode({
      autoscaling = {
        enabled = true
        minReplicas = 3
        maxReplicas = 8
      }
      ingress = {
        enabled = true
        tls = [
          {
            secretName = "dgsn-frontend-tls-prod"
            hosts = ["app.dgsn.io"]
          }
        ]
      }
    })
  ]

  depends_on = [
    module.backend,
  ]
}

output "cluster_endpoint" {
  value = module.aws.cluster_endpoint
}

output "vpc_id" {
  value = module.aws.vpc_id
}

output "redis_endpoint" {
  value = module.aws.redis_endpoint
}

output "rds_endpoint" {
  value = module.aws.rds_endpoint
}

output "s3_bucket" {
  value = module.aws.s3_bucket
}
