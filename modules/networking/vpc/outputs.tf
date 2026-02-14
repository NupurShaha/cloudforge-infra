# modules/networking/vpc/outputs.tf
#
# These outputs are consumed by downstream modules via Terragrunt dependencies.
# GKE needs the VPC, subnet, and secondary range names.
# Cloud SQL needs the VPC self_link for private IP peering.

output "vpc_id" {
  description = "The ID of the VPC"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "The name of the VPC"
  value       = google_compute_network.vpc.name
}

output "vpc_self_link" {
  description = "The self link of the VPC (used by Cloud SQL, Memorystore)"
  value       = google_compute_network.vpc.self_link
}

output "subnets" {
  description = "Map of subnet name to subnet details"
  value = {
    for k, v in google_compute_subnetwork.subnets : k => {
      name      = v.name
      id        = v.id
      self_link = v.self_link
      cidr      = v.ip_cidr_range
      region    = v.region
      secondary_ranges = {
        for sr in v.secondary_ip_range : sr.range_name => sr.ip_cidr_range
      }
    }
  }
}

# Convenience outputs for the most common references
output "app_subnet_name" {
  description = "Name of the app subnet (for GKE)"
  value       = google_compute_subnetwork.subnets["app"].name
}

output "app_subnet_self_link" {
  description = "Self link of the app subnet (for GKE)"
  value       = google_compute_subnetwork.subnets["app"].self_link
}

output "pods_range_name" {
  description = "Name of the secondary range for GKE pods"
  value       = "pods"
}

output "services_range_name" {
  description = "Name of the secondary range for GKE services"
  value       = "services"
}

output "data_subnet_self_link" {
  description = "Self link of the data subnet (for Cloud SQL, Redis)"
  value       = google_compute_subnetwork.subnets["data"].self_link
}

output "private_service_range" {
  description = "Name of the private service access range"
  value       = google_compute_global_address.private_service_range.name
}

output "nat_ip" {
  description = "Cloud NAT external IP (auto-allocated)"
  value       = var.enable_cloud_nat ? google_compute_router_nat.nat[0].name : null
}
