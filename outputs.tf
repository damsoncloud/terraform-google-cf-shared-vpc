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
      `secondary_ip_ranges`, CIDR ranges by range name;
    `routers` of the Cloud NAT gateways by region, e.g. for hybrid connectivity:
      `id`, `name`;
      `nat_ip_addresses`, the IP addresses reserved with `MANUAL_ONLY`, empty with `AUTO_ONLY`.
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
    routers = { for key, router in google_compute_router.nat : local.nat_regions[key].region => {
      id               = router.id
      name             = router.name
      nat_ip_addresses = [for address_key, address in google_compute_address.nat : address.address if local.nat_ip_addresses[address_key].router_key == key]
    } if local.nat_regions[key].environment == environment }
  } }
}
