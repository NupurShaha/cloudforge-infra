# modules/security/secret-manager/variables.tf

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

variable "secrets" {
  description = "Map of secrets to create in Secret Manager"
  type = map(object({
    description = optional(string, "")
  }))
  default = {}
}

variable "kms_keyring_name" {
  description = "Name of the KMS keyring"
  type        = string
}

variable "kms_keys" {
  description = "Map of KMS keys to create"
  type = map(object({
    rotation_period = optional(string, "7776000s")
    purpose         = optional(string, "ENCRYPT_DECRYPT")
  }))
  default = {}
}
