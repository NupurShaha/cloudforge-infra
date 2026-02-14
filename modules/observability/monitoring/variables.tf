# modules/observability/monitoring/variables.tf

variable "project_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "common_labels" {
  type    = map(string)
  default = {}
}

variable "notification_email" {
  description = "Email for alert notifications"
  type        = string
}

variable "alert_policies" {
  description = "Map of alert policies to create"
  type = map(object({
    display_name = string
    metric       = string
    threshold    = number
    duration     = optional(string, "300s")
    comparison     = optional(string, "COMPARISON_GT")
    resource_type = string
    resource_type  = string
  }))
  default = {}
}

variable "uptime_checks" {
  description = "Map of uptime checks"
  type = map(object({
    host    = string
    path    = optional(string, "/")
    period  = optional(string, "300s")
    timeout = optional(string, "10s")
  }))
  default = {}
}

variable "log_sinks" {
  description = "Map of log sinks"
  type = map(object({
    destination = string    # "storage" or "bigquery"
    filter      = string
    description = optional(string, "")
  }))
  default = {}
}

variable "log_exclusions" {
  description = "Map of log exclusions for cost optimization"
  type = map(object({
    filter      = string
    description = optional(string, "")
  }))
  default = {}
}
