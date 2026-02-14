# policies/opa/restrict_regions.rego
#
# Policy: Resources can only be created in approved GCP regions.
# Prevents accidental deployment to expensive or non-compliant regions.

package cloudforge.regions

import rego.v1

allowed_regions := {"asia-south1", "asia-south2"}

deny contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "create"
    region := object.get(resource.change.after, "region", null)
    region != null
    not region in allowed_regions
    msg := sprintf(
        "Resource '%s' is in region '%s'. Allowed regions: %v",
        [resource.address, region, allowed_regions]
    )
}

deny contains msg if {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "create"
    location := object.get(resource.change.after, "location", null)
    location != null
    not location in allowed_regions
    msg := sprintf(
        "Resource '%s' is in location '%s'. Allowed locations: %v",
        [resource.address, location, allowed_regions]
    )
}
