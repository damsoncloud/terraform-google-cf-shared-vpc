locals {
  environments = { for name, folder in var.folders : name => folder.short_name if folder.short_name != null }

  subnets = merge([
    for environment, network in var.networks : {
      for region, subnet in network.subnets : "${environment}/${region}" => merge(subnet, {
        environment = environment
        region      = region
      })
    }
  ]...)
}

# The default routes are deleted, so that all the routes of the network are managed in code
resource "google_compute_network" "environments" {
  for_each = var.networks

  project                         = google_compute_shared_vpc_host_project.host[each.value.host_project].project
  name                            = "${local.environments[each.key]}-vpc"
  description                     = "Shared VPC network of the ${each.key} environment"
  auto_create_subnetworks         = false
  routing_mode                    = each.value.routing_mode
  delete_default_routes_on_create = true
}

# Cloud NAT and Private Google Access both need a route to the default internet gateway
resource "google_compute_route" "internet" {
  for_each = google_compute_network.environments

  project          = each.value.project
  network          = each.value.id
  name             = "${local.environments[each.key]}-internet-route"
  description      = "Egress to the internet through Cloud NAT and to Google APIs through Private Google Access"
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

resource "google_compute_subnetwork" "environments" {
  for_each = local.subnets

  project                  = google_compute_network.environments[each.value.environment].project
  network                  = google_compute_network.environments[each.value.environment].id
  name                     = "${local.environments[each.value.environment]}-${each.value.region}-subnet"
  region                   = each.value.region
  ip_cidr_range            = each.value.ip_cidr_range
  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ip_ranges

    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }

  # Otherwise removing the last secondary range leaves it in place
  send_secondary_ip_range_if_empty = true

  log_config {
    aggregation_interval = var.flow_logs.aggregation_interval
    flow_sampling        = var.flow_logs.flow_sampling
    metadata             = var.flow_logs.metadata
  }
}
