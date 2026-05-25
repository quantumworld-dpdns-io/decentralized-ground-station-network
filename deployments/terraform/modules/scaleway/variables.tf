variable "project_name" {
  type    = string
  default = "dgsn"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "scw_zone" {
  type    = string
  default = "fr-par-1"
}

variable "scw_region" {
  type    = string
  default = "fr-par"
}

variable "k8s_version" {
  type    = string
  default = "1.31"
}

variable "node_type" {
  type    = string
  default = "DEV1-M"
}

variable "pool_size" {
  type    = number
  default = 3
}

variable "pool_min_size" {
  type    = number
  default = 3
}

variable "pool_max_size" {
  type    = number
  default = 10
}

variable "db_node_type" {
  type    = string
  default = "db-dev-m"
}

variable "db_volume_size" {
  type    = number
  default = 50
}

variable "db_ha" {
  type    = bool
  default = true
}

variable "db_user" {
  type    = string
  default = "dgsn"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "redis_version" {
  type    = string
  default = "7.2"
}

variable "redis_node_type" {
  type    = string
  default = "RED1-M"
}

variable "redis_cluster_size" {
  type    = number
  default = 3
}
