# modules/dr/dr-database/main.tf
#
# Cross-region read replica of the primary Cloud SQL instance.
# In a DR event, this replica gets promoted to primary.
# RTO: ~5-10 minutes (promotion + DNS switch)
# RPO: ~seconds (async replication lag)

variable "project_id" { type = string }
variable "environment" { type = string }
variable "primary_instance_name" { type = string }
variable "dr_vpc_self_link" { type = string }
variable "common_labels" { type = map(string); default = {} }

locals {
  dr_region = "asia-south2"
}

resource "google_sql_database_instance" "dr_replica" {
  name                 = "${var.primary_instance_name}-dr-replica"
  project              = var.project_id
  region               = local.dr_region
  database_version     = "POSTGRES_15"
  master_instance_name = var.primary_instance_name
  deletion_protection  = true

  replica_configuration {
    failover_target = true   # Can be promoted to primary
  }

  settings {
    tier              = "db-custom-2-8192"   # Adequate for DR
    availability_type = "ZONAL"              # HA not needed for replica
    disk_size         = 20
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.dr_vpc_self_link
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    user_labels = merge(var.common_labels, {
      role = "dr-replica"
    })
  }
}

output "dr_replica_name" { value = google_sql_database_instance.dr_replica.name }
output "dr_replica_ip" { value = google_sql_database_instance.dr_replica.private_ip_address }
output "dr_replica_connection_name" { value = google_sql_database_instance.dr_replica.connection_name }
