# policies/opa/enforce_encryption.rego
#
# Policy: Cloud SQL instances must have backup enabled
# and all GCS buckets must have versioning on critical buckets.

package cloudforge.encryption

import rego.v1

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_sql_database_instance"
    resource.change.actions[_] == "create"
    settings := resource.change.after.settings[0]
    backup := settings.backup_configuration[0]
    backup.enabled != true
    msg := sprintf(
        "Cloud SQL instance '%s' must have backups enabled.",
        [resource.address]
    )
}

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_sql_database_instance"
    resource.change.actions[_] == "create"
    settings := resource.change.after.settings[0]
    ip_config := settings.ip_configuration[0]
    ip_config.ipv4_enabled == true
    msg := sprintf(
        "Cloud SQL instance '%s' must not have a public IP. Use private networking only.",
        [resource.address]
    )
}

deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "google_redis_instance"
    resource.change.actions[_] == "create"
    resource.change.after.auth_enabled != true
    msg := sprintf(
        "Redis instance '%s' must have AUTH enabled.",
        [resource.address]
    )
}
