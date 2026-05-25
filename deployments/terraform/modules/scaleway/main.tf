terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.0"
    }
  }
}

provider "scaleway" {
  zone   = var.scw_zone
  region = var.scw_region
}

# VPC
resource "scaleway_vpc" "main" {
  name = "${var.project_name}-${var.environment}-vpc"
  tags = [var.environment, var.project_name]
}

resource "scaleway_vpc_private_network" "main" {
  name   = "${var.project_name}-${var.environment}-pn"
  vpc_id = scaleway_vpc.main.id
}

# K8s Cluster
resource "scaleway_k8s_cluster" "main" {
  name    = "${var.project_name}-${var.environment}"
  version = var.k8s_version
  cni     = "cilium"
  tags    = [var.environment, var.project_name]

  auto_upgrade {
    enable = true
    window = "any"
  }

  private_network_id = scaleway_vpc_private_network.main.id
}

resource "scaleway_k8s_pool" "main" {
  cluster_id  = scaleway_k8s_cluster.main.id
  name        = "${var.project_name}-pool-${var.environment}"
  node_type   = var.node_type
  size        = var.pool_size
  min_size    = var.pool_min_size
  max_size    = var.pool_max_size
  autoscaling = true
  autohealing = true

  tags = [var.environment, var.project_name]
}

# Database
resource "scaleway_rdb_instance" "main" {
  name              = "${var.project_name}-${var.environment}-db"
  engine            = "PostgreSQL-16"
  node_type         = var.db_node_type
  volume_size_in_gb = var.db_volume_size
  is_ha_cluster     = var.db_ha

  tags = [var.environment, var.project_name]
}

resource "scaleway_rdb_database" "main" {
  instance_id = scaleway_rdb_instance.main.id
  name        = "dgsn"
}

resource "scaleway_rdb_user" "main" {
  instance_id = scaleway_rdb_instance.main.id
  name        = var.db_user
  password    = var.db_password
}

# Redis
resource "scaleway_redis_cluster" "main" {
  name        = "${var.project_name}-${var.environment}-redis"
  version     = var.redis_version
  node_type   = var.redis_node_type
  cluster_size = var.redis_cluster_size

  tags = [var.environment, var.project_name]
}

# Container Registry
resource "scaleway_registry_namespace" "main" {
  name        = "${var.project_name}-${var.environment}"
  description = "DGSN container registry"
  is_public   = false
}

# Object Storage
resource "scaleway_object_bucket" "data" {
  name = "${var.project_name}-${var.environment}-data"
  tags = [var.environment, var.project_name]
}

resource "scaleway_object_bucket" "backups" {
  name = "${var.project_name}-${var.environment}-backups"
  tags = [var.environment, var.project_name]
}
