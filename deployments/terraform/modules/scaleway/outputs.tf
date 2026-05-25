output "cluster_id" {
  value = scaleway_k8s_cluster.main.id
}

output "cluster_kubeconfig" {
  value     = scaleway_k8s_cluster.main.kubeconfig
  sensitive = true
}

output "database_endpoint" {
  value = scaleway_rdb_instance.main.endpoint_ip
}

output "database_port" {
  value = scaleway_rdb_instance.main.endpoint_port
}

output "redis_endpoint" {
  value = scaleway_redis_cluster.main.endpoint_ip
}

output "redis_port" {
  value = scaleway_redis_cluster.main.port
}

output "registry_endpoint" {
  value = scaleway_registry_namespace.main.endpoint
}

output "data_bucket" {
  value = scaleway_object_bucket.data.name
}
