# modules/observability/monitoring/main.tf
#
# Creates:
# - Notification channels (email)
# - Alert policies (CPU, memory, connections, etc.)
# - Uptime checks
# - Log sinks (to GCS/BigQuery for analysis)
# - Log exclusions (cost optimization)
# - Custom dashboard

# ─── Notification Channel ─────────────────────────────────────
resource "google_monitoring_notification_channel" "email" {
  display_name = "CloudForge ${var.environment} Alerts"
  type         = "email"
  project      = var.project_id

  labels = {
    email_address = var.notification_email
  }
}

# ─── Alert Policies ──────────────────────────────────────────
resource "google_monitoring_alert_policy" "alerts" {
  for_each = var.alert_policies

  display_name = "[${upper(var.environment)}] ${each.value.display_name}"
  project      = var.project_id
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = each.value.display_name
    condition_threshold {
      filter          = "metric.type=\"${each.value.metric}\" AND resource.type=\"*\""
      duration        = each.value.duration
      comparison      = each.value.comparison
      threshold_value = each.value.threshold

      trigger {
        count = 1
      }

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "1800s"    # Auto-resolve after 30 min
  }

  user_labels = merge(var.common_labels, {
    alert_type = each.key
  })
}

# ─── Uptime Checks ───────────────────────────────────────────
resource "google_monitoring_uptime_check_config" "checks" {
  for_each = {
    for k, v in var.uptime_checks : k => v
    if v.host != ""    # Skip checks with empty host
  }

  display_name = "[${upper(var.environment)}] ${each.key} uptime"
  project      = var.project_id
  timeout      = each.value.timeout
  period       = each.value.period

  http_check {
    path         = each.value.path
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = each.value.host
    }
  }
}

# ─── Log Sink to GCS (Audit Logs) ────────────────────────────
resource "google_storage_bucket" "log_archive" {
  count = length(var.log_sinks) > 0 ? 1 : 0

  name          = "${var.project_id}-${var.environment}-log-archive"
  project       = var.project_id
  location      = "asia-south1"
  storage_class = "NEARLINE"
  force_destroy = var.environment != "prod"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle_rule {
    condition {
      age = 90    # Keep audit logs for 90 days
    }
    action {
      type = "Delete"
    }
  }

  labels = merge(var.common_labels, {
    purpose = "log-archive"
  })
}

resource "google_logging_project_sink" "sinks" {
  for_each = var.log_sinks

  name        = "${var.environment}-${each.key}"
  project     = var.project_id
  description = each.value.description
  filter      = each.value.filter

  destination = (
    each.value.destination == "storage"
    ? "storage.googleapis.com/${google_storage_bucket.log_archive[0].name}"
    : "bigquery.googleapis.com/projects/${var.project_id}/datasets/${var.environment}_logs"
  )

  unique_writer_identity = true
}

# Grant the log sink writer access to the GCS bucket
resource "google_storage_bucket_iam_member" "log_sink_writer" {
  for_each = {
    for k, v in var.log_sinks : k => v
    if v.destination == "storage"
  }

  bucket = google_storage_bucket.log_archive[0].name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.sinks[each.key].writer_identity
}

# ─── Log Exclusions (Cost Optimization) ──────────────────────
resource "google_logging_project_exclusion" "exclusions" {
  for_each = var.log_exclusions

  name        = "${var.environment}-${each.key}"
  project     = var.project_id
  description = each.value.description
  filter      = each.value.filter
}

# ─── Custom Dashboard ─────────────────────────────────────────
resource "google_monitoring_dashboard" "overview" {
  project        = var.project_id
  dashboard_json = jsonencode({
    displayName = "CloudForge ${upper(var.environment)} Overview"
    gridLayout = {
      columns = 2
      widgets = [
        {
          title = "GKE Node CPU Utilization"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"kubernetes.io/node/cpu/allocatable_utilization\" resource.type=\"k8s_node\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_MEAN"
                  }
                }
              }
            }]
          }
        },
        {
          title = "GKE Node Memory Utilization"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"kubernetes.io/node/memory/allocatable_utilization\" resource.type=\"k8s_node\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_MEAN"
                  }
                }
              }
            }]
          }
        },
        {
          title = "Cloud SQL CPU Utilization"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\" resource.type=\"cloudsql_database\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_MEAN"
                  }
                }
              }
            }]
          }
        },
        {
          title = "Redis Memory Usage"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"redis.googleapis.com/stats/memory/usage_ratio\" resource.type=\"redis_instance\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_MEAN"
                  }
                }
              }
            }]
          }
        }
      ]
    }
  })
}
