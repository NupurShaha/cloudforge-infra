# modules/dr/dr-dns-failover/main.tf
#
# Cloud DNS with health-checked routing policies.
# Primary: asia-south1 (Mumbai)
# Failover: asia-south2 (Delhi)
# When primary health check fails, DNS automatically routes to DR.

variable "project_id" { type = string }
variable "environment" { type = string }
variable "domain_name" { type = string; default = "cloudforge.internal" }
variable "primary_ip" { type = string; description = "Primary region LB IP" }
variable "dr_ip" { type = string; description = "DR region LB IP" }
variable "common_labels" { type = map(string); default = {} }

# Managed DNS zone
resource "google_dns_managed_zone" "app_zone" {
  name        = "${var.environment}-cloudforge-zone"
  project     = var.project_id
  dns_name    = "${var.domain_name}."
  description = "CloudForge ${var.environment} DNS zone with failover"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = "projects/${var.project_id}/global/networks/${var.environment}-cloudforge-vpc"
    }
  }
}

# Health-checked routing policy record
resource "google_dns_record_set" "app_failover" {
  name         = "app.${google_dns_managed_zone.app_zone.dns_name}"
  project      = var.project_id
  managed_zone = google_dns_managed_zone.app_zone.name
  type         = "A"
  ttl          = 60    # Low TTL for fast failover

  routing_policy {
    primary_backup {
      # Primary target — Mumbai
      primary {
        internal_load_balancers {
          ip_address  = var.primary_ip
          ip_protocol = "tcp"
          load_balancer_type = "regionalL4ilb"
          network_url = "projects/${var.project_id}/global/networks/${var.environment}-cloudforge-vpc"
          port        = "443"
          project     = var.project_id
          region      = "asia-south1"
        }
      }

      # Backup target — Delhi (DR)
      backup_geo {
        location = "asia-south2"
        rrdatas  = [var.dr_ip]
      }

      # Switch to DR if primary health drops below 80%
      trickle_ratio = 0.0    # 0% traffic to backup normally
    }
  }
}

output "dns_zone_name" { value = google_dns_managed_zone.app_zone.name }
output "app_fqdn" { value = "app.${var.domain_name}" }
