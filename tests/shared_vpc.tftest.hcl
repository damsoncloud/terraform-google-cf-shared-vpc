mock_provider "google" {}

variables {
  domain = "example.com"
  host_projects = {
    prod    = { project_id = "cmn-shared-vpcs-prod-c3d4", number = "444444444441" }
    nonprod = { project_id = "cmn-shared-vpcs-nonprod-c3d4", number = "444444444442" }
  }
}

run "host_projects" {
  assert {
    condition = (
      toset(keys(google_project_service.host)) == toset(["prod/compute.googleapis.com", "nonprod/compute.googleapis.com"]) &&
      google_compute_shared_vpc_host_project.host["prod"].project == "cmn-shared-vpcs-prod-c3d4" &&
      google_compute_shared_vpc_host_project.host["nonprod"].project == "cmn-shared-vpcs-nonprod-c3d4" &&
      output.host_project_ids == { prod = "cmn-shared-vpcs-prod-c3d4", nonprod = "cmn-shared-vpcs-nonprod-c3d4" }
    )
    error_message = "Each project must be enabled as a Shared VPC host, with the Compute Engine API."
  }

  assert {
    condition = (
      length(google_project_iam_member.network_admins) == 4 &&
      google_project_iam_member.network_admins["nonprod/roles/compute.securityAdmin"].project == "cmn-shared-vpcs-nonprod-c3d4" &&
      google_project_iam_member.network_admins["prod/roles/compute.networkAdmin"].project == "cmn-shared-vpcs-prod-c3d4" &&
      alltrue([for binding in google_project_iam_member.network_admins : binding.member == "group:gcp-network-admins@example.com"])
    )
    error_message = "The network administrators group must administer the networks and the firewall rules of every host project."
  }
}

run "custom_network_admins_group" {
  command = plan

  variables {
    network_admins_group_name = "gcp-common-network-admins"
  }

  assert {
    condition     = alltrue([for binding in google_project_iam_member.network_admins : binding.member == "group:gcp-common-network-admins@example.com"])
    error_message = "The network administrators group must be configurable."
  }
}

run "no_host_projects" {
  command = plan

  variables {
    host_projects = {}
  }

  expect_failures = [var.host_projects]
}
