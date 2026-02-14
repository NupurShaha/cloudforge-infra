# modules/data/cloud-sql/main.tf
#
# Creates:
# - Cloud SQL PostgreSQL instance with private IP
# - Application database and user
# - Memorystore Redis instance
# - GCS buckets with lifecycle rules

# ─── Random suffix for globally unique names ──────────────────
resource "random_id" "db_suffix" {
  byte_length = 4
}

# ─── Cloud SQL Instance ──────────────────────────────────────
resource "google_sql_database_instance" "primary" {
  name                = "${var.instance_name}-${random_id.db_suffix.hex}"
  project             = var.project_id
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_size         = var.disk_size
    disk_type         = var.disk_type
    disk_autoresize   = var.disk_autoresize
    edition           = "ENTERPRISE"

    # Private IP only — no public exposure
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.vpc_self_link
      enable_private_path_for_google_cloud_services = true
    }

    # Backup configuration
    backup_configuration {
      enabled                        = var.backup_enabled
      point_in_time_recovery_enabled = var.point_in_time_recovery_enabled
      start_time                     = var.backup_start_time
      transaction_log_retention_days = var.transaction_log_retention_days

      backup_retention_settings {
        retained_backups = var.retained_backups
        retention_unit   = "COUNT"
      }
    }

    # Maintenance window
    maintenance_window {
      day          = var.maintenance_day
      hour         = var.maintenance_hour
      update_track = "stable"
    }

    # Security flags
    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }
    database_flags {
      name  = "log_connections"
      value = "on"
    }
    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }

    # Insights for query performance monitoring
    insights_config {
      query_insights_enabled  = true
      query_plans_per_minute  = 5
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }

    user_labels = merge(var.common_labels, {
      service = "database"
    })
  }

  lifecycle {
    # Prevent accidental destruction of database in prod
    # In dev, deletion_protection = false allows destroy
    prevent_destroy = false
  }
}

# ─── Database ─────────────────────────────────────────────────
resource "google_sql_database" "app_db" {
  name     = var.database_name
  project  = var.project_id
  instance = google_sql_database_instance.primary.name
}

# ─── Database User ────────────────────────────────────────────
# Password is generated and stored — in production, use Secret Manager
resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "google_sql_user" "app_user" {
  name     = var.db_user
  project  = var.project_id
  instance = google_sql_database_instance.primary.name
  password = random_password.db_password.result

  deletion_policy = "ABANDON"    # Don't fail on destroy
}

# ─── Store password in Secret Manager ─────────────────────────
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.environment}-db-password"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = var.common_labels
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

# ─── Memorystore Redis ────────────────────────────────────────
resource "google_redis_instance" "cache" {
  name               = var.redis_name
  project            = var.project_id
  region             = var.region
  tier               = var.redis_tier
  memory_size_gb     = var.redis_memory_gb
  redis_version      = var.redis_version
  authorized_network = var.vpc_self_link
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  auth_enabled            = true
  transit_encryption_mode = "SERVER_AUTHENTICATION"

  maintenance_policy {
    weekly_maintenance_window {
      day = "SUNDAY"
      start_time {
        hours   = 4
        minutes = 0
      }
    }
  }

  redis_configs = {
    maxmemory-policy = "allkeys-lru"
    notify-keyspace-events = ""
  }

  labels = merge(var.common_labels, {
    service = "cache"
  })

  lifecycle {
    prevent_destroy = false
  }
}

# ─── Cloud Storage Buckets ────────────────────────────────────
resource "google_storage_bucket" "buckets" {
  for_each = var.storage_buckets

  name          = "${var.project_id}-${var.environment}-${each.key}"
  project       = var.project_id
  location      = each.value.location
  storage_class = each.value.storage_class
  force_destroy = var.environment != "prod"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"    # Never public

  versioning {
    enabled = each.value.versioning
  }

  lifecycle_rule {
    condition {
      age = each.value.lifecycle_age
    }
    action {
      type = "Delete"
    }
  }

  # Versioned buckets: clean up old versions
  dynamic "lifecycle_rule" {
    for_each = each.value.versioning ? [1] : []
    content {
      condition {
        num_newer_versions = 3
        with_state         = "ARCHIVED"
      }
      action {
        type = "Delete"
      }
    }
  }

  labels = merge(var.common_labels, {
    purpose = each.key
  })
}
