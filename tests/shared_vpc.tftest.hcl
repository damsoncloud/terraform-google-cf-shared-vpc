mock_provider "google" {}

variables {
  domain = "example.com"
  host_projects = {
    prod    = { project_id = "cmn-shared-vpcs-prod-c3d4", number = "444444444441" }
    nonprod = { project_id = "cmn-shared-vpcs-nonprod-c3d4", number = "444444444442" }
  }
  folders = {
    common        = { id = "folders/1", short_name = "cmn", common = true }
    development   = { id = "folders/2", short_name = "dev" }
    certification = { id = "folders/3", short_name = "cert" }
    production    = { id = "folders/4", short_name = "prod" }
    legacy        = { id = "folders/5" }
  }
  networks = {
    development = {
      host_project = "nonprod"
      subnets = {
        europe-west4 = { ip_cidr_range = "10.10.0.0/24" }
        europe-west1 = { ip_cidr_range = "10.10.1.0/24" }
      }
    }
    certification = {
      host_project = "nonprod"
      cloud_nat    = { enabled = false }
      subnets = {
        europe-west4 = { ip_cidr_range = "10.20.0.0/24" }
      }
    }
    production = {
      host_project = "prod"
      routing_mode = "REGIONAL"
      subnets = {
        europe-west4 = { ip_cidr_range = "10.30.0.0/24", secondary_ip_ranges = { pods = "10.130.0.0/20", services = "10.131.0.0/24" } }
        europe-west1 = { ip_cidr_range = "10.30.1.0/24" }
      }
    }
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
    networks      = {}
  }

  expect_failures = [var.host_projects]
}

run "networks" {
  assert {
    condition = (
      google_compute_network.environments["development"].name == "dev-vpc" &&
      google_compute_network.environments["development"].project == "cmn-shared-vpcs-nonprod-c3d4" &&
      google_compute_network.environments["certification"].project == "cmn-shared-vpcs-nonprod-c3d4" &&
      google_compute_network.environments["production"].name == "prod-vpc" &&
      google_compute_network.environments["production"].project == "cmn-shared-vpcs-prod-c3d4" &&
      alltrue([for network in google_compute_network.environments : !network.auto_create_subnetworks && network.delete_default_routes_on_create])
    )
    error_message = "Each environment must have a custom mode network in its host project, without the default routes."
  }

  assert {
    condition = (
      google_compute_network.environments["development"].routing_mode == "GLOBAL" &&
      google_compute_network.environments["production"].routing_mode == "REGIONAL"
    )
    error_message = "The routing mode must default to GLOBAL and be configurable per network."
  }

  assert {
    condition = (
      google_compute_route.internet["production"].name == "prod-internet-route" &&
      google_compute_route.internet["production"].project == "cmn-shared-vpcs-prod-c3d4" &&
      google_compute_route.internet["production"].network == google_compute_network.environments["production"].id &&
      alltrue([for route in google_compute_route.internet : route.dest_range == "0.0.0.0/0" && route.next_hop_gateway == "default-internet-gateway"])
    )
    error_message = "Each network must have an explicit route to the default internet gateway."
  }
}

run "subnets" {
  assert {
    condition = (
      toset(keys(google_compute_subnetwork.environments)) == toset([
        "development/europe-west4", "development/europe-west1", "certification/europe-west4", "production/europe-west4", "production/europe-west1"
      ]) &&
      google_compute_subnetwork.environments["development/europe-west1"].name == "dev-europe-west1-subnet" &&
      google_compute_subnetwork.environments["development/europe-west1"].region == "europe-west1" &&
      google_compute_subnetwork.environments["development/europe-west1"].ip_cidr_range == "10.10.1.0/24" &&
      google_compute_subnetwork.environments["development/europe-west1"].network == google_compute_network.environments["development"].id &&
      google_compute_subnetwork.environments["production/europe-west4"].project == "cmn-shared-vpcs-prod-c3d4"
    )
    error_message = "Each network must have a subnet per region, named after the environment and the region."
  }

  assert {
    condition = alltrue([for subnet in google_compute_subnetwork.environments : (
      subnet.private_ip_google_access &&
      subnet.log_config[0].aggregation_interval == "INTERVAL_5_SEC" &&
      subnet.log_config[0].flow_sampling == 0.5 &&
      subnet.log_config[0].metadata == "INCLUDE_ALL_METADATA"
    )])
    error_message = "Each subnet must have Private Google Access and flow logs with all metadata."
  }

  assert {
    condition = (
      length(google_compute_subnetwork.environments["development/europe-west4"].secondary_ip_range) == 0 &&
      output.networks["production"].subnets["europe-west4"].secondary_ip_ranges == { pods = "10.130.0.0/20", services = "10.131.0.0/24" }
    )
    error_message = "The secondary ranges must be created by range name."
  }

  assert {
    condition = (
      toset(keys(output.networks)) == toset(["development", "certification", "production"]) &&
      output.networks["production"].project_id == "cmn-shared-vpcs-prod-c3d4" &&
      output.networks["production"].name == "prod-vpc" &&
      toset(keys(output.networks["production"].subnets)) == toset(["europe-west4", "europe-west1"]) &&
      output.networks["certification"].subnets["europe-west4"].name == "cert-europe-west4-subnet"
    )
    error_message = "The networks must be returned by environment, with their subnets by region."
  }
}

run "custom_flow_logs" {
  command = plan

  variables {
    flow_logs = {
      aggregation_interval = "INTERVAL_1_MIN"
      flow_sampling        = 0.1
    }
  }

  assert {
    condition = alltrue([for subnet in google_compute_subnetwork.environments : (
      subnet.log_config[0].aggregation_interval == "INTERVAL_1_MIN" &&
      subnet.log_config[0].flow_sampling == 0.1 &&
      subnet.log_config[0].metadata == "INCLUDE_ALL_METADATA"
    )])
    error_message = "The flow logs must be configurable."
  }
}

run "invalid_flow_logs" {
  command = plan

  variables {
    flow_logs = {
      aggregation_interval = "INTERVAL_2_MIN"
      flow_sampling        = 0
      metadata             = "ALL"
    }
  }

  expect_failures = [var.flow_logs]
}

run "network_not_an_environment" {
  command = plan

  variables {
    networks = {
      legacy = { host_project = "nonprod", subnets = { europe-west4 = { ip_cidr_range = "10.40.0.0/24" } } }
    }
  }

  expect_failures = [var.networks]
}

run "unknown_host_project" {
  command = plan

  variables {
    networks = {
      development = { host_project = "dev", subnets = { europe-west4 = { ip_cidr_range = "10.10.0.0/24" } } }
    }
  }

  expect_failures = [var.networks]
}

run "invalid_networks" {
  command = plan

  variables {
    networks = {
      development = {
        host_project = "nonprod"
        routing_mode = "global"
        subnets = {
          west4 = { ip_cidr_range = "10.10.0.0/33", secondary_ip_ranges = { Pods = "10.110.0.0" } }
        }
      }
      production = { host_project = "prod", subnets = {} }
    }
  }

  expect_failures = [var.networks]
}

run "cloud_nat" {
  assert {
    condition = (
      toset(keys(google_compute_router.nat)) == toset(["development/europe-west4", "development/europe-west1", "production/europe-west4", "production/europe-west1"]) &&
      google_compute_router.nat["development/europe-west1"].name == "dev-europe-west1-router" &&
      google_compute_router.nat["development/europe-west1"].region == "europe-west1" &&
      google_compute_router.nat["development/europe-west1"].network == google_compute_network.environments["development"].id &&
      google_compute_router.nat["production/europe-west4"].project == "cmn-shared-vpcs-prod-c3d4"
    )
    error_message = "Each region of a network with Cloud NAT must have a Cloud Router, and the networks without it none."
  }

  assert {
    condition = (
      google_compute_router_nat.nat["production/europe-west1"].name == "prod-europe-west1-nat" &&
      google_compute_router_nat.nat["production/europe-west1"].router == "prod-europe-west1-router" &&
      google_compute_router_nat.nat["production/europe-west1"].region == "europe-west1" &&
      google_compute_router_nat.nat["production/europe-west1"].project == "cmn-shared-vpcs-prod-c3d4" &&
      alltrue([for nat in google_compute_router_nat.nat : (
        nat.nat_ip_allocate_option == "AUTO_ONLY" &&
        length(nat.nat_ips) == 0 &&
        nat.source_subnetwork_ip_ranges_to_nat == "ALL_SUBNETWORKS_ALL_IP_RANGES" &&
        !nat.enable_dynamic_port_allocation &&
        nat.log_config[0].enable &&
        nat.log_config[0].filter == "ALL"
      )])
    )
    error_message = "Each Cloud Router must have a Cloud NAT gateway translating all ranges, logging all connections."
  }

  assert {
    condition = (
      output.networks["development"].routers["europe-west4"].name == "dev-europe-west4-router" &&
      output.networks["development"].routers["europe-west4"].nat_ip_addresses == [] &&
      output.networks["certification"].routers == {} &&
      length(google_compute_address.nat) == 0
    )
    error_message = "The routers must be returned by network and region."
  }
}

run "custom_cloud_nat" {
  command = plan

  variables {
    cloud_nat = {
      log_filter                     = "ERRORS_ONLY"
      min_ports_per_vm               = 128
      enable_dynamic_port_allocation = true
      max_ports_per_vm               = 4096
    }
  }

  assert {
    condition = alltrue([for nat in google_compute_router_nat.nat : (
      nat.log_config[0].filter == "ERRORS_ONLY" &&
      nat.min_ports_per_vm == 128 &&
      nat.enable_dynamic_port_allocation &&
      nat.max_ports_per_vm == 4096
    )])
    error_message = "The Cloud NAT gateways must be configurable."
  }
}

run "invalid_cloud_nat" {
  command = plan

  variables {
    cloud_nat = {
      log_filter       = "NONE"
      max_ports_per_vm = 4096
    }
  }

  expect_failures = [var.cloud_nat]
}

run "manual_nat_ip_addresses" {
  variables {
    networks = {
      development = {
        host_project = "nonprod"
        subnets      = { europe-west4 = { ip_cidr_range = "10.10.0.0/24" } }
      }
      production = {
        host_project = "prod"
        cloud_nat    = { ip_allocation = "MANUAL_ONLY", ip_address_count = 2 }
        subnets = {
          europe-west4 = { ip_cidr_range = "10.30.0.0/24" }
          europe-west1 = { ip_cidr_range = "10.30.1.0/24" }
        }
      }
    }
  }

  assert {
    condition = (
      toset(keys(google_compute_address.nat)) == toset([
        "production/europe-west4/1", "production/europe-west4/2", "production/europe-west1/1", "production/europe-west1/2"
      ]) &&
      google_compute_address.nat["production/europe-west1/2"].name == "prod-europe-west1-nat-ip-2" &&
      google_compute_address.nat["production/europe-west1/2"].region == "europe-west1" &&
      google_compute_address.nat["production/europe-west1/2"].project == "cmn-shared-vpcs-prod-c3d4" &&
      google_compute_address.nat["production/europe-west1/2"].address_type == "EXTERNAL"
    )
    error_message = "MANUAL_ONLY must reserve the given number of IP addresses per region."
  }

  assert {
    condition = (
      google_compute_router_nat.nat["production/europe-west1"].nat_ip_allocate_option == "MANUAL_ONLY" &&
      toset(google_compute_router_nat.nat["production/europe-west1"].nat_ips) == toset([
        google_compute_address.nat["production/europe-west1/1"].self_link, google_compute_address.nat["production/europe-west1/2"].self_link
      ]) &&
      google_compute_router_nat.nat["development/europe-west4"].nat_ip_allocate_option == "AUTO_ONLY" &&
      length(output.networks["production"].routers["europe-west4"].nat_ip_addresses) == 2
    )
    error_message = "Each Cloud NAT gateway with MANUAL_ONLY must use the IP addresses reserved in its region only."
  }
}

run "invalid_nat_ip_addresses" {
  command = plan

  variables {
    networks = {
      development = {
        host_project = "nonprod"
        cloud_nat    = { ip_allocation = "MANUAL", ip_address_count = 0.5 }
        subnets      = { europe-west4 = { ip_cidr_range = "10.10.0.0/24" } }
      }
    }
  }

  expect_failures = [var.networks]
}
