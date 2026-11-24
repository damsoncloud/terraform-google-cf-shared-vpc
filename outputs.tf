output "host_project_ids" {
  description = "IDs of the Shared VPC host projects, enabled as hosts, by name, for cf-gcp-project's service projects."
  value       = { for name, host in google_compute_shared_vpc_host_project.host : name => host.project }
}

output "networks" {
  description = <<-EOT
  The VPC networks by environment name, for cf-gcp-project's service projects:
    `id`, `name`, `self_link`;
    `project_id` of the host project;
    `subnets` by region:
      `id`, `name`, `self_link`, `ip_cidr_range`;
      `secondary_ip_ranges`, CIDR ranges by range name.
  EOT
  value = { for environment, network in google_compute_network.environments : environment => {
    id         = network.id
    name       = network.name
    self_link  = network.self_link
    project_id = network.project
    subnets = { for key, subnet in google_compute_subnetwork.environments : local.subnets[key].region => {
      id                  = subnet.id
      name                = subnet.name
      self_link           = subnet.self_link
      ip_cidr_range       = subnet.ip_cidr_range
      secondary_ip_ranges = { for range in subnet.secondary_ip_range : range.range_name => range.ip_cidr_range }
    } if local.subnets[key].environment == environment }
  } }
}
