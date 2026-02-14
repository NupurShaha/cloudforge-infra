# modules/data/cloud-sql/outputs.tf

output "sql_instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.primary.name
}

output "sql_connection_name" {
  description = "Cloud SQL connection name (project:region:instance)"
  value       = google_sql_database_instance.primary.connection_name
}

output "sql_private_ip" {
  description = "Private IP of the Cloud SQL instance"
  value       = google_sql_database_instance.primary.private_ip_address
}

output "database_name" {
  value = google_sql_database.app_db.name
}

output "db_user" {
  value = google_sql_user.app_user.name
}

output "db_password_secret_id" {
  description = "Secret Manager secret ID containing the DB password"
  value       = google_secret_manager_secret.db_password.secret_id
}

output "redis_host" {
  description = "Memorystore Redis host IP"
  value       = google_redis_instance.cache.host
}

output "redis_port" {
  description = "Memorystore Redis port"
  value       = google_redis_instance.cache.port
}

output "redis_instance_id" {
  value = google_redis_instance.cache.id
}

output "bucket_names" {
  description = "Map of bucket purpose to bucket name"
  value       = { for k, v in google_storage_bucket.buckets : k => v.name }
}

output "bucket_urls" {
  description = "Map of bucket purpose to gs:// URL"
  value       = { for k, v in google_storage_bucket.buckets : k => v.url }
}
