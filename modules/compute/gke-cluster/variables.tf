# modules/compute/gke-cluster/variables.tf

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,38}[a-z0-9]$", var.cluster_name))
    error_message = "Cluster name must be 4-40 lowercase alphanumeric or hyphens."
  }
}

# ─── Network references (from networking module) ─────────────
variable "vpc_self_link" {
  description = "Self link of the VPC"
  type        = string
}

variable "subnet_self_link" {
  description = "Self link of the subnet for GKE nodes"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the secondary IP range for pods"
  type        = string
}

variable "services_range_name" {
  description = "Name of the secondary IP range for services"
  type        = string
}

# ─── Private cluster config ──────────────────────────────────
variable "enable_private_nodes" {
  description = "Whether nodes have only private IPs"
  type        = bool
  default     = true
}

variable "enable_private_endpoint" {
  description = "Whether the master endpoint is private only"
  type        = bool
  default     = false   # Set true in prod with bastion
}

variable "master_cidr" {
  description = "CIDR block for the GKE master (must be /28)"
  type        = string
  default     = "172.16.0.0/28"

  validation {
    condition     = can(cidrhost(var.master_cidr, 0)) && endswith(var.master_cidr, "/28")
    error_message = "Master CIDR must be a valid /28 CIDR block."
  }
}

variable "master_authorized_networks" {
  description = "Networks authorized to access the Kubernetes API"
  type = list(object({
    display_name = string
    cidr_block   = string
  }))
  default = []
}

# ─── Node pools ──────────────────────────────────────────────
variable "node_pools" {
  description = "Map of node pool configurations"
  type = map(object({
    machine_type = string
    spot         = optional(bool, false)
    min_count    = optional(number, 1)
    max_count    = optional(number, 3)
    disk_size_gb = optional(number, 50)
    disk_type    = optional(string, "pd-standard")
    auto_repair  = optional(bool, true)
    auto_upgrade = optional(bool, true)
    labels       = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))

  validation {
    condition     = length(var.node_pools) > 0
    error_message = "At least one node pool must be defined."
  }
}

# ─── Cluster config ──────────────────────────────────────────
variable "release_channel" {
  description = "GKE release channel"
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "Release channel must be RAPID, REGULAR, or STABLE."
  }
}

variable "maintenance_start_time" {
  description = "Start time for maintenance window (RFC 3339)"
  type        = string
  default     = "2024-01-01T04:00:00Z"
}

variable "maintenance_end_time" {
  description = "End time for maintenance window (RFC 3339)"
  type        = string
  default     = "2024-01-01T08:00:00Z"
}

variable "maintenance_recurrence" {
  description = "Recurrence spec for maintenance window (RRULE)"
  type        = string
  default     = "FREQ=WEEKLY;BYDAY=SA,SU"
}

variable "tenant_namespaces" {
  description = "Kubernetes namespaces to create for each tenant"
  type        = list(string)
  default     = []
}

variable "common_labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}
