# modules/networking/vpc/main.tf
#
# Creates:
# - Custom VPC (no auto-subnets)
# - Subnets with optional secondary ranges (for GKE pods/services)
# - Private Service Access (for Cloud SQL, Memorystore private IPs)
# - Firewall rules (via dynamic blocks)
# - Cloud Router + Cloud NAT (for outbound from private instances)

# ─── VPC ──────────────────────────────────────────────────────
resource "google_compute_network" "vpc" {
  name                    = "${var.environment}-${var.vpc_name}"
  project                 = var.project_id
  auto_create_subnetworks = false             # Custom subnets only
  routing_mode            = "REGIONAL"
  mtu                     = 1460
  description             = "CloudForge ${var.environment} VPC"

  delete_default_routes_on_create = false
}

# ─── Subnets ──────────────────────────────────────────────────
# Uses for_each with a complex map — shows advanced variable handling
resource "google_compute_subnetwork" "subnets" {
  for_each = var.subnets

  name                     = "${var.environment}-${each.key}-subnet"
  project                  = var.project_id
  region                   = each.value.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = each.value.cidr
  private_ip_google_access = true             # Access Google APIs without public IP
  description              = each.value.purpose

  # Dynamic secondary ranges — only created if defined
  # This is key for GKE (pods + services need their own ranges)
  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }

  # Flow logs for security monitoring
  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ─── Private Service Access ───────────────────────────────────
# Required for Cloud SQL and Memorystore to use private IPs
resource "google_compute_global_address" "private_service_range" {
  name          = "${var.environment}-private-service-range"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
  description   = "Reserved range for GCP managed services (Cloud SQL, Redis)"
}

resource "google_service_networking_connection" "private_service_access" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]

  deletion_policy = "ABANDON"  # Don't fail destroy if peering is still in use
}

# ─── Firewall Rules ──────────────────────────────────────────
# Dynamic blocks to handle variable number of protocols per rule
resource "google_compute_firewall" "rules" {
  for_each = var.firewall_rules

  name        = "${var.environment}-${each.key}"
  project     = var.project_id
  network     = google_compute_network.vpc.id
  direction   = each.value.direction
  priority    = each.value.priority
  description = each.value.description

  source_ranges = each.value.direction == "INGRESS" ? each.value.ranges : null

  # Dynamic allow blocks — each protocol gets its own block
  dynamic "allow" {
    for_each = each.value.protocols
    content {
      protocol = allow.key
      ports    = length(allow.value) > 0 ? allow.value : null
    }
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# ─── Explicit deny-all ingress rule ──────────────────────────
# Lower priority than allow rules, catches everything else
resource "google_compute_firewall" "deny_all_ingress" {
  name        = "${var.environment}-deny-all-ingress"
  project     = var.project_id
  network     = google_compute_network.vpc.id
  direction   = "INGRESS"
  priority    = 65534
  description = "Explicit deny-all ingress (defense in depth)"

  source_ranges = ["0.0.0.0/0"]

  deny {
    protocol = "all"
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# ─── Cloud Router ─────────────────────────────────────────────
resource "google_compute_router" "router" {
  count = var.enable_cloud_nat ? 1 : 0

  name    = "${var.environment}-cloud-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id

  bgp {
    asn = 64514
  }
}

# ─── Cloud NAT ────────────────────────────────────────────────
# Allows private GKE nodes to reach the internet (pull images, etc.)
resource "google_compute_router_nat" "nat" {
  count = var.enable_cloud_nat ? 1 : 0

  name                               = "${var.environment}-cloud-nat"
  project                            = var.project_id
  router                             = google_compute_router.router[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  # Tuning for production-like behavior
  min_ports_per_vm                    = 64
  max_ports_per_vm                    = 4096
  enable_endpoint_independent_mapping = false
  tcp_established_idle_timeout_sec    = 1200
  tcp_transitory_idle_timeout_sec     = 30
}
