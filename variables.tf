variable "domain" {
  description = "Domain of the organisation's groups."
  type        = string
}

variable "flow_logs" {
  description = <<-EOT
  VPC Flow Logs configuration of all the subnets:
    `aggregation_interval`,
    `flow_sampling` (0 to 1),
    `metadata` (`INCLUDE_ALL_METADATA`, `EXCLUDE_ALL_METADATA` or `CUSTOM_METADATA`).
  EOT
  type = object({
    aggregation_interval = optional(string, "INTERVAL_5_SEC")
    flow_sampling        = optional(number, 0.5)
    metadata             = optional(string, "INCLUDE_ALL_METADATA")
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["INTERVAL_5_SEC", "INTERVAL_30_SEC", "INTERVAL_1_MIN", "INTERVAL_5_MIN", "INTERVAL_10_MIN", "INTERVAL_15_MIN"], var.flow_logs.aggregation_interval)
    error_message = "The aggregation interval must be one of INTERVAL_5_SEC, INTERVAL_30_SEC, INTERVAL_1_MIN, INTERVAL_5_MIN, INTERVAL_10_MIN or INTERVAL_15_MIN."
  }

  validation {
    condition     = var.flow_logs.flow_sampling > 0 && var.flow_logs.flow_sampling <= 1
    error_message = "The flow sampling must be greater than 0 and at most 1."
  }

  validation {
    condition     = contains(["INCLUDE_ALL_METADATA", "EXCLUDE_ALL_METADATA", "CUSTOM_METADATA"], var.flow_logs.metadata)
    error_message = "The metadata must be INCLUDE_ALL_METADATA, EXCLUDE_ALL_METADATA or CUSTOM_METADATA."
  }
}

variable "folders" {
  description = <<-EOT
  The folders by folder name, e.g. the `folders` output of cf-hierarchy:
    `id`, the resource name (`folders/<id>`);
    `short_name`, the environment's short name, null for folders other than environments;
    `common`, whether it is the common environment.
  The environments' short names prefix the names of their networks' resources.
  EOT
  type = map(object({
    id         = string
    short_name = optional(string)
    common     = optional(bool, false)
  }))
  nullable = false
}

variable "host_projects" {
  description = <<-EOT
  The Shared VPC host projects by name, e.g. the `shared_vpc_projects` output of cf-organization: `project_id`.
  A host project and its service projects must be in the same VPC Service Controls perimeter, so the environments inside and outside the perimeter have separate host projects.
  EOT
  type = map(object({
    project_id = string
  }))

  validation {
    condition     = length(var.host_projects) > 0
    error_message = "At least one host project is required."
  }
}

variable "network_admins_group_name" {
  description = <<-EOT
  Name of the group administering the networks, their firewall rules and external connectivity in the host projects, without the domain.
  EOT
  type        = string
  default     = "gcp-network-admins"
  nullable    = false
}

variable "networks" {
  description = <<-EOT
  The VPC networks by environment name, one of the `folders` with a short name:
    `host_project`, the name of its host project in `host_projects`, inside the perimeter for the environments in it;
    `routing_mode`, `GLOBAL` or `REGIONAL`;
    `subnets` by region, e.g. the primary and DR regions:
      `ip_cidr_range`;
      `secondary_ip_ranges`, CIDR ranges by range name, e.g. for GKE Pods and Services.
  EOT
  type = map(object({
    host_project = string
    routing_mode = optional(string, "GLOBAL")
    subnets = map(object({
      ip_cidr_range       = string
      secondary_ip_ranges = optional(map(string), {})
    }))
  }))
  nullable = false

  validation {
    condition     = alltrue([for name in keys(var.networks) : contains([for folder_name, folder in var.folders : folder_name if folder.short_name != null], name)])
    error_message = "Each network must be named after an environment, one of the folders with a short name."
  }

  validation {
    condition     = alltrue([for network in values(var.networks) : contains(keys(var.host_projects), network.host_project)])
    error_message = "Each network's host project must be one of the host projects."
  }

  validation {
    condition     = alltrue([for network in values(var.networks) : contains(["GLOBAL", "REGIONAL"], network.routing_mode)])
    error_message = "The routing mode must be GLOBAL or REGIONAL."
  }

  validation {
    condition     = alltrue([for network in values(var.networks) : length(network.subnets) > 0])
    error_message = "Each network must have at least one subnet."
  }

  validation {
    condition     = alltrue(flatten([for network in values(var.networks) : [for region in keys(network.subnets) : can(regex("^[a-z]+-[a-z]+[0-9]+$", region))]]))
    error_message = "Each subnet must be keyed by a region, e.g. europe-west4."
  }

  validation {
    condition = alltrue(flatten([for network in values(var.networks) : [
      for subnet in values(network.subnets) : [for cidr in concat([subnet.ip_cidr_range], values(subnet.secondary_ip_ranges)) : can(cidrnetmask(cidr))]
    ]]))
    error_message = "Each subnet's primary and secondary ranges must be IPv4 CIDR ranges, e.g. 10.10.0.0/24."
  }

  validation {
    condition = alltrue(flatten([for network in values(var.networks) : [
      for subnet in values(network.subnets) : [for name in keys(subnet.secondary_ip_ranges) : can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", name))]
    ]]))
    error_message = "Each secondary range name must be 1-63 lowercase letters, digits or hyphens, starting with a letter and not ending with a hyphen."
  }
}
