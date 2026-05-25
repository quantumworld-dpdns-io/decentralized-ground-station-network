output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 encoded EKS cluster CA certificate"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_token" {
  description = "EKS cluster authentication token"
  value       = data.tls_certificate.eks.certificates[0].sha1_fingerprint
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "redis_endpoint" {
  description = "ElastiCache Redis cluster endpoint"
  value       = module.redis.cache_cluster_address
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = module.redis.cache_cluster_port
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.rds.db_instance_address
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = module.rds.db_instance_port
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.postgres.id
}

output "s3_bucket" {
  description = "S3 bucket name for signal storage"
  value       = aws_s3_bucket.signals.bucket
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for signal storage"
  value       = aws_s3_bucket.signals.arn
}

output "backend_iam_role_arn" {
  description = "Backend service IAM role ARN"
  value       = aws_iam_role.dgsn_backend.arn
}

output "signal_iam_role_arn" {
  description = "Signal service IAM role ARN"
  value       = aws_iam_role.dgsn_signal.arn
}

output "backend_security_group_id" {
  description = "Backend service security group ID"
  value       = aws_security_group.dgsn_backend.id
}

output "crypto_security_group_id" {
  description = "Crypto service security group ID"
  value       = aws_security_group.dgsn_crypto.id
}

output "quantum_security_group_id" {
  description = "Quantum service security group ID"
  value       = aws_security_group.dgsn_quantum.id
}

output "signal_security_group_id" {
  description = "Signal service security group ID"
  value       = aws_security_group.dgsn_signal.id
}

output "eks_cluster_oidc_provider_arn" {
  description = "EKS cluster OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}
