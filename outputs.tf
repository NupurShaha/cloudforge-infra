# modules/compute/gke-cluster/outputs.tf

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "The endpoint for the GKE cluster API server"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "The CA certificate for the cluster (base64 encoded)"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "The location (region/zone) of the cluster"
  value       = google_container_cluster.primary.location
}

output "workload_identity_pool" {
  description = "Workload Identity pool for binding K8s SAs to GCP SAs"
  value       = "${var.project_id}.svc.id.goog"
}

output "node_service_account_email" {
  description = "Email of the GKE node service account"
  value       = google_service_account.gke_nodes.email
}

output "cluster_id" {
  description = "The unique ID of the cluster"
  value       = google_container_cluster.primary.id
}

# Connection command for convenience
output "get_credentials_command" {
  description = "gcloud command to get cluster credentials"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region} --project ${var.project_id}"
}
