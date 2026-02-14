# modules/data/cloud-sql/variables.tf

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "common_labels" {
  type    = map(string)
  default = {}
}

# ─── Cloud SQL ────────────────────────────────────────────────
variable "instance_name" {
  description = "Cloud SQL instance name"
  type        = string
}

variable "database_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "POSTGRES_15"
}

variable "tier" {
  description = "Machine tier for Cloud SQL"
  type        = string
  default     = "db-f1-micro"
}

variable "availability_type" {
  description = "ZONAL or REGIONAL (HA)"
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "Must be ZONAL or REGIONAL."
  }
}

variable "disk_size" {
  type    = number
  default = 10
}

variable "disk_type" {
  type    = string
  default = "PD_HDD"
}

variable "disk_autoresize" {
  type    = bool
  default = false
}

variable "vpc_self_link" {
  description = "VPC self link for private IP"
  type        = string
}

variable "database_name" {
  type    = string
  default = "cloudforge"
}

variable "db_user" {
  type    = string
  default = "cloudforge_app"
}

variable "backup_enabled" {
  type    = bool
  default = true
}

variable "point_in_time_recovery_enabled" {
  type    = bool
  default = false
}

variable "backup_start_time" {
  type    = string
  default = "03:00"
}

variable "transaction_log_retention_days" {
  type    = number
  default = 1
}

variable "retained_backups" {
  type    = number
  default = 3
}

variable "maintenance_day" {
  type    = number
  default = 7
}

variable "maintenance_hour" {
  type    = number
  default = 4
}

variable "deletion_protection" {
  type    = bool
  default = false
}

# ─── Memorystore Redis ────────────────────────────────────────
variable "redis_name" {
  type = string
}

variable "redis_tier" {
  type    = string
  default = "BASIC"
}

variable "redis_memory_gb" {
  type    = number
  default = 1
}

variable "redis_version" {
  type    = string
  default = "REDIS_7_0"
}

# ─── Cloud Storage ────────────────────────────────────────────
variable "storage_buckets" {
  description = "Map of GCS buckets to create"
  type = map(object({
    location      = string
    storage_class = string
    versioning    = optional(bool, false)
    lifecycle_age = optional(number, 30)
  }))
  default = {}
}
