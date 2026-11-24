locals {
  nat_regions = { for key, subnet in local.subnets : key => merge(subnet, var.networks[subnet.environment].cloud_nat) if var.networks[subnet.environment].cloud_nat.enabled }

  nat_ip_addresses = merge([
    for key, region in local.nat_regions : {
      for index in range(1, region.ip_address_count + 1) : "${key}/${index}" => merge(region, { router_key = key, index = index })
    } if region.ip_allocation == "MANUAL_ONLY"
  ]...)
}

resource "google_compute_address" "nat" {
  for_each = local.nat_ip_addresses

  project      = google_compute_network.environments[each.value.environment].project
  name         = "${local.environments[each.value.environment]}-${each.value.region}-nat-ip-${each.value.index}"
  description  = "Cloud NAT IP address of the ${each.value.environment} environment in ${each.value.region}"
  region       = each.value.region
  address_type = "EXTERNAL"
}

resource "google_compute_router" "nat" {
  for_each = local.nat_regions

  project     = google_compute_network.environments[each.value.environment].project
  network     = google_compute_network.environments[each.value.environment].id
  name        = "${local.environments[each.value.environment]}-${each.value.region}-router"
  description = "Cloud NAT of the ${each.value.environment} environment in ${each.value.region}"
  region      = each.value.region
}

resource "google_compute_router_nat" "nat" {
  for_each = local.nat_regions

  project                            = google_compute_router.nat[each.key].project
  router                             = google_compute_router.nat[each.key].name
  region                             = google_compute_router.nat[each.key].region
  name                               = "${local.environments[each.value.environment]}-${each.value.region}-nat"
  nat_ip_allocate_option             = each.value.ip_allocation
  nat_ips                            = [for key, address in google_compute_address.nat : address.self_link if local.nat_ip_addresses[key].router_key == each.key]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  min_ports_per_vm                   = var.cloud_nat.min_ports_per_vm
  enable_dynamic_port_allocation     = var.cloud_nat.enable_dynamic_port_allocation
  max_ports_per_vm                   = var.cloud_nat.max_ports_per_vm

  log_config {
    enable = true
    filter = var.cloud_nat.log_filter
  }
}
