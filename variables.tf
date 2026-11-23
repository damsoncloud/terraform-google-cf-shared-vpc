variable "domain" {
  description = "Domain of the organisation's groups."
  type        = string
}

variable "host_projects" {
  description = "The Shared VPC host projects by name, e.g. the `shared_vpc_projects` output of cf-organization: `project_id`. A host project and its service projects must be in the same VPC Service Controls perimeter, so the environments inside and outside the perimeter have separate host projects."
  type = map(object({
    project_id = string
  }))

  validation {
    condition     = length(var.host_projects) > 0
    error_message = "At least one host project is required."
  }
}

variable "network_admins_group_name" {
  description = "Name of the group administering the networks, their firewall rules and external connectivity in the host projects, without the domain."
  type        = string
  default     = "gcp-network-admins"
  nullable    = false
}
