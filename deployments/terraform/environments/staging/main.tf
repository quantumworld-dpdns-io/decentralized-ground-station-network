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
    bucket         = "dgsn-tf-state-staging"
    key            = "terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "dgsn-tf-locks-staging"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "DGSN"
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
  default     = "staging"
}

variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-west-2"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
  default     = "dgsn-staging"
}

variable "instance_types" {
  type        = list(string)
  description = "EC2 instance types for worker nodes (spot instances)"
  default     = ["t3.large", "t3a.large"]
}

variable "spot_instance_types" {
  type        = list(string)
  description = "Spot instance types for cost optimization"
  default     = ["t3.large", "t3a.large", "m5.large", "m5a.large"]
}

variable "min_size" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 4
}

variable "max_size" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 15
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
  default     = "10.1.0.0/16"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnet CIDRs"
  default     = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnet CIDRs"
  default     = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
}

variable "pqc_enabled" {
  type        = bool
  description = "Enable Post-Quantum Cryptography"
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

  use_spot_instances = true
  spot_instance_types = var.spot_instance_types
  on_demand_base_capacity = 2
}

resource "kubernetes_namespace" "dgsn" {
  metadata {
    name = "dgsn-staging"

    labels = {
      name = "dgsn-staging"
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

module "infra" {
  source = "../../../helm/dgsn-infra"

  depends_on = [
    kubernetes_namespace.dgsn,
    kubernetes_namespace.monitoring,
  ]
}

module "backend" {
  source = "../../../helm/dgsn-backend"

  namespace = kubernetes_namespace.dgsn.metadata[0].name

  depends_on = [
    module.infra,
  ]
}

module "crypto" {
  source = "../../../helm/dgsn-crypto"

  namespace = kubernetes_namespace.dgsn.metadata[0].name

  depends_on = [
    module.infra,
  ]
}

module "quantum" {
  source = "../../../helm/dgsn-quantum"

  namespace = kubernetes_namespace.dgsn.metadata[0].name

  depends_on = [
    module.infra,
  ]
}

module "signal" {
  source = "../../../helm/dgsn-signal"

  namespace = kubernetes_namespace.dgsn.metadata[0].name

  depends_on = [
    module.infra,
  ]
}

module "frontend" {
  source = "../../../helm/dgsn-frontend"

  namespace = kubernetes_namespace.dgsn.metadata[0].name

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

output "s3_bucket" {
  value = module.aws.s3_bucket
}
