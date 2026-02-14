# modules/dr/dr-network/main.tf
#
# Disaster Recovery: Secondary region network infrastructure.
# Mirrors the primary VPC structure in asia-south2 (Delhi).
# This module is IaC-ready — apply only during DR activation.

variable "project_id" { type = string }
variable "environment" { type = string }
variable "primary_vpc_self_link" { type = string }
variable "common_labels" { type = map(string); default = {} }

locals {
  dr_region = "asia-south2"   # Delhi — paired with asia-south1 (Mumbai)
}

resource "google_compute_network" "dr_vpc" {
  name                    = "${var.environment}-dr-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "DR VPC in ${local.dr_region}"
}

resource "google_compute_subnetwork" "dr_app_subnet" {
  name                     = "${var.environment}-dr-app-subnet"
  project                  = var.project_id
  region                   = local.dr_region
  network                  = google_compute_network.dr_vpc.id
  ip_cidr_range            = "10.50.0.0/20"
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.60.0.0/16"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.70.0.0/20"
  }
}

# VPC Peering between primary and DR VPCs
resource "google_compute_network_peering" "primary_to_dr" {
  name         = "${var.environment}-primary-to-dr"
  network      = var.primary_vpc_self_link
  peer_network = google_compute_network.dr_vpc.self_link
}

resource "google_compute_network_peering" "dr_to_primary" {
  name         = "${var.environment}-dr-to-primary"
  network      = google_compute_network.dr_vpc.self_link
  peer_network = var.primary_vpc_self_link

  depends_on = [google_compute_network_peering.primary_to_dr]
}

# Cloud NAT for DR region
resource "google_compute_router" "dr_router" {
  name    = "${var.environment}-dr-router"
  project = var.project_id
  region  = local.dr_region
  network = google_compute_network.dr_vpc.id
  bgp { asn = 64515 }
}

resource "google_compute_router_nat" "dr_nat" {
  name                               = "${var.environment}-dr-nat"
  project                            = var.project_id
  router                             = google_compute_router.dr_router.name
  region                             = local.dr_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

output "dr_vpc_self_link" { value = google_compute_network.dr_vpc.self_link }
output "dr_subnet_self_link" { value = google_compute_subnetwork.dr_app_subnet.self_link }
