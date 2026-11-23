output "host_project_ids" {
  description = "IDs of the Shared VPC host projects, enabled as hosts, by name, for cf-gcp-project's service projects."
  value       = { for name, host in google_compute_shared_vpc_host_project.host : name => host.project }
}
