# modules/observability/monitoring/outputs.tf

output "notification_channel_id" {
  value = google_monitoring_notification_channel.email.id
}

output "alert_policy_ids" {
  value = { for k, v in google_monitoring_alert_policy.alerts : k => v.id }
}

output "dashboard_id" {
  value = google_monitoring_dashboard.overview.id
}

output "log_archive_bucket" {
  value = length(google_storage_bucket.log_archive) > 0 ? google_storage_bucket.log_archive[0].name : null
}
