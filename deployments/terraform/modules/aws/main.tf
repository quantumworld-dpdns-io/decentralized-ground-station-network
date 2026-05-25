terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.dgsn.endpoint
}

locals {
  vpc_id = module.vpc.vpc_id
  tags = {
    Environment = var.environment
    Project     = "DGSN"
    ManagedBy   = "Terraform"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.environment}-dgsn-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, length(var.private_subnets))
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = false
  one_nat_gateway_per_az = var.multi_az

  enable_vpn_gateway          = false
  enable_dns_hostnames        = true
  enable_dns_support          = true
  enable_flow_log             = var.enable_vpc_flow_logs
  cloudwatch_log_group_retention_in_days = 30

  flow_log_iam_role_arn = aws_iam_role.vpc_flow_log.arn
  flow_log_destination_type = "cloud-watch-logs"

  tags = local.tags
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_iam_role" "vpc_flow_log" {
  name = "${var.environment}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "vpc_flow_log" {
  role       = aws_iam_role.vpc_flow_log.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonVPCFlowLogFullAccess"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    on_demand = {
      capacity_type  = "ON_DEMAND"
      instance_types = var.instance_types
      min_size       = var.min_size
      max_size       = var.max_size
      desired_size   = var.min_size

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        AmazonEKS_CNI_Policy         = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      }

      tags = merge(local.tags, {
        "k8s.io/cluster-autoscaler/enabled" = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      })
    }
  }

  dynamic "eks_managed_node_groups" {
    for_each = var.use_spot_instances ? ["spot"] : []
    content {
      capacity_type  = "SPOT"
      instance_types = var.spot_instance_types
      min_size       = 0
      max_size       = var.max_size
      desired_size   = 0

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        AmazonEKS_CNI_Policy         = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      }

      tags = merge(local.tags, {
        "k8s.io/cluster-autoscaler/enabled" = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
        "kubernetes.io/lifecycle" = "spot"
      })
    }
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  tags = local.tags
}

resource "aws_security_group" "dgsn_backend" {
  name        = "${var.environment}-dgsn-backend"
  description = "Allow backend traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Backend HTTP API"
  }

  ingress {
    from_port   = 50051
    to_port     = 50051
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Backend gRPC API"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_security_group" "dgsn_crypto" {
  name        = "${var.environment}-dgsn-crypto"
  description = "Allow crypto service traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 50051
    to_port     = 50051
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Crypto gRPC API"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_security_group" "dgsn_quantum" {
  name        = "${var.environment}-dgsn-quantum"
  description = "Allow quantum service traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 50052
    to_port     = 50052
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Quantum gRPC API"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_security_group" "dgsn_signal" {
  name        = "${var.environment}-dgsn-signal"
  description = "Allow signal service traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 50053
    to_port     = 50053
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Signal gRPC API"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

module "redis" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "~> 7.0"

  engine           = "redis"
  engine_version   = "7.1"
  family           = "redis7"
  node_type        = "cache.t3.medium"
  num_cache_nodes  = 3
  cluster_mode     = "enabled"
  num_node_groups  = 3
  replicas_per_node_group = 1

  subnet_group_name = "${var.environment}-redis-subnet-group"
  security_group_ids = [aws_security_group.dgsn_backend.id]

  subnets = module.vpc.private_subnets

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  tags = local.tags
}

resource "aws_security_group" "postgres" {
  name        = "${var.environment}-postgres"
  description = "Allow PostgreSQL traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
    description = "PostgreSQL"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.environment}-dgsn"

  engine               = "postgres"
  engine_version       = "15"
  family               = "postgres15"
  instance_class       = "db.t3.large"
  allocated_storage    = 100
  max_allocated_storage = 500
  storage_encrypted    = true
  storage_type         = "gp3"

  db_subnet_group_name = "${var.environment}-dgsn-subnet-group"
  vpc_security_group_ids = [aws_security_group.postgres.id]

  subnet_ids = module.vpc.private_subnets

  create_db_subnet_group = true

  database_name = "dgsn"
  username      = "dgsn_admin"
  password      = var.rds_password

  multi_az = var.multi_az

  performance_insights_enabled = true
  performance_insights_retention_period = 7

  backup_retention_period = 7
  copy_tags_to_snapshot = true

  tags = local.tags
}

resource "aws_s3_bucket" "signals" {
  bucket = "${var.environment}-dgsn-signals-${data.aws_caller_identity.current.account_id}"
  force_destroy = false

  tags = merge(local.tags, {
    Name = "${var.environment}-dgsn-signals"
  })
}

resource "aws_s3_bucket_acl" "signals" {
  bucket = aws_s3_bucket.signals.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "signals" {
  bucket = aws_s3_bucket.signals.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "signals" {
  bucket = aws_s3_bucket.signals.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "signals" {
  bucket = aws_s3_bucket.signals.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "signals" {
  bucket = aws_s3_bucket.signals.id

  rule {
    id     = "raw-signals-retention"
    prefix = "raw/"
    status = "Enabled"

    transition {
      days          = 7
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  rule {
    id     = "processed-signals-retention"
    prefix = "processed/"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 730
    }
  }
}

resource "aws_iam_role" "dgsn_backend" {
  name = "${var.environment}-dgsn-backend-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_provider_arn, "/^arn:aws:iam::\\d+:oidc-provider\\//", "")}:sub" = "system:serviceaccount:dgsn-${var.environment}:dgsn-backend"
          }
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "dgsn_backend_s3" {
  role       = aws_iam_role.dgsn_backend.name
  policy_arn = aws_iam_policy.dgsn_backend_s3.arn
}

resource "aws_iam_policy" "dgsn_backend_s3" {
  name        = "${var.environment}-dgsn-backend-s3"
  description = "Allow backend access to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.signals.arn,
          "${aws_s3_bucket.signals.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "dgsn_signal" {
  name = "${var.environment}-dgsn-signal-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_provider_arn, "/^arn:aws:iam::\\d+:oidc-provider\\//", "")}:sub" = "system:serviceaccount:dgsn-${var.environment}:dgsn-signal"
          }
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "dgsn_signal_s3" {
  role       = aws_iam_role.dgsn_signal.name
  policy_arn = aws_iam_policy.dgsn_signal_s3.arn
}

resource "aws_iam_policy" "dgsn_signal_s3" {
  name        = "${var.environment}-dgsn-signal-s3"
  description = "Allow signal service access to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.signals.arn,
          "${aws_s3_bucket.signals.arn}/*"
        ]
      }
    ]
  })
}
