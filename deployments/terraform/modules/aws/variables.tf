variable "project_name" {
  description = "Project name"
  type        = string
  default     = "dgsn"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "allowed_cidrs" {
  description = "Allowed CIDR blocks for API access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.31"
}

variable "node_instance_types" {
  description = "EC2 instance types for node group"
  type        = list(string)
  default     = ["m6i.large", "m6a.large"]
}

variable "node_desired_size" {
  description = "Desired node count"
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Minimum node count"
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Maximum node count"
  type        = number
  default     = 20
}

variable "postgres_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.3"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.r6g.large"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 100
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "dgsn_admin"
}

variable "db_password" {
  description = "Database master password (auto-generated if empty)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_backup_retention" {
  description = "Database backup retention in days"
  type        = number
  default     = 30
}

variable "redis_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.r6g.large"
}

variable "redis_num_nodes" {
  description = "Number of Redis cache nodes"
  type        = number
  default     = 3
}

variable "ecr_repositories" {
  description = "ECR repository names"
  type        = list(string)
  default     = ["backend", "frontend", "crypto", "quantum", "signal"]
}
