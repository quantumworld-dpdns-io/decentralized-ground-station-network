variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
  default     = "dev"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
  default     = "dgsn-cluster"
}

variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-west-2"
}

variable "instance_types" {
  type        = list(string)
  description = "EC2 instance types for on-demand worker nodes"
  default     = ["t3.medium"]
}

variable "spot_instance_types" {
  type        = list(string)
  description = "EC2 instance types for spot worker nodes"
  default     = ["t3.large", "t3a.large", "m5.large"]
}

variable "min_size" {
  type        = number
  description = "Minimum number of worker nodes in node group"
  default     = 3
}

variable "max_size" {
  type        = number
  description = "Maximum number of worker nodes in node group"
  default     = 10
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnet CIDR blocks (one per AZ)"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnet CIDR blocks (one per AZ)"
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "pqc_enabled" {
  type        = bool
  description = "Enable Post-Quantum Cryptography (NIST SP 800-186 compliant)"
  default     = false
}

variable "multi_az" {
  type        = bool
  description = "Enable multi-AZ high availability"
  default     = false
}

variable "use_spot_instances" {
  type        = bool
  description = "Enable spot instances for cost optimization"
  default     = false
}

variable "on_demand_base_capacity" {
  type        = number
  description = "Number of on-demand base instances when using spot"
  default     = 0
}

variable "enable_vpc_flow_logs" {
  type        = bool
  description = "Enable VPC flow logs for network monitoring"
  default     = false
}

variable "enable_cloudwatch" {
  type        = bool
  description = "Enable CloudWatch integration"
  default     = false
}

variable "rds_password" {
  type        = string
  description = "RDS PostgreSQL master password"
  sensitive   = true
  default     = ""
}
