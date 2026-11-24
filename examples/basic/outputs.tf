output "host_project_ids" {
  description = "IDs of the Shared VPC host projects, by name."
  value       = module.shared_vpc.host_project_ids
}

output "networks" {
  description = "The VPC networks by environment name, with their subnets and Cloud Routers by region."
  value       = module.shared_vpc.networks
}
