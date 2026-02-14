# modules/networking/vpc/variables.tf

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string

  validation {
    condition     = can(regex("^(asia-south1|asia-south2|us-central1|europe-west1)$", var.region))
    error_message = "Region must be one of: asia-south1, asia-south2, us-central1, europe-west1."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,28}[a-z0-9]$", var.vpc_name))
    error_message = "VPC name must be 4-30 lowercase alphanumeric characters or hyphens."
  }
}

variable "subnets" {
  description = "Map of subnets to create with their CIDR ranges and optional secondary ranges"
  type = map(object({
    cidr             = string
    region           = string
    purpose          = optional(string, "")
    secondary_ranges = optional(map(string), {})
  }))

  validation {
    condition     = length(var.subnets) > 0
    error_message = "At least one subnet must be defined."
  }
}

variable "firewall_rules" {
  description = "Map of firewall rules to create"
  type = map(object({
    direction   = string
    priority    = number
    ranges      = list(string)
    protocols   = map(list(string))   # e.g., { tcp = ["80","443"], icmp = [] }
    description = optional(string, "")
  }))
  default = {}
}

variable "enable_cloud_nat" {
  description = "Whether to create Cloud NAT for outbound internet from private instances"
  type        = bool
  default     = true
}

variable "common_labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}
