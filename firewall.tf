locals {
  # The source range of IAP TCP forwarding
  iap_source_range = "35.235.240.0/20"

  firewall_rules = merge(
    {
      for environment, network in var.networks : "${environment}/allow-iap-ingress" => {
        environment             = environment
        name                    = "allow-iap-ingress"
        description             = "Administrative access through IAP TCP forwarding"
        direction               = "INGRESS"
        action                  = "allow"
        priority                = 1000
        ranges                  = [local.iap_source_range]
        source_tags             = []
        source_service_accounts = []
        target_tags             = []
        target_service_accounts = []
        protocols               = { tcp = network.iap_ports }
      } if length(network.iap_ports) > 0
    },
    {
      # Explicit, unlike the implied deny rule, so that denied connections are logged
      for environment in keys(var.networks) : "${environment}/deny-all-ingress" => {
        environment             = environment
        name                    = "deny-all-ingress"
        description             = "Deny-by-default ingress, logging denied connections"
        direction               = "INGRESS"
        action                  = "deny"
        priority                = 65534
        ranges                  = ["0.0.0.0/0"]
        source_tags             = []
        source_service_accounts = []
        target_tags             = []
        target_service_accounts = []
        protocols               = { all = [] }
      }
    },
    merge([
      for environment, network in var.networks : {
        for name, rule in network.firewall_rules : "${environment}/${name}" => merge(rule, { environment = environment, name = name })
      }
    ]...)
  )
}

resource "google_compute_firewall" "rules" {
  for_each = local.firewall_rules

  project                 = google_compute_network.environments[each.value.environment].project
  network                 = google_compute_network.environments[each.value.environment].id
  name                    = "${local.environments[each.value.environment]}-${each.value.name}"
  description             = each.value.description
  direction               = each.value.direction
  priority                = each.value.priority
  source_ranges           = each.value.direction == "INGRESS" ? each.value.ranges : null
  destination_ranges      = each.value.direction == "EGRESS" ? each.value.ranges : null
  source_tags             = length(each.value.source_tags) > 0 ? each.value.source_tags : null
  source_service_accounts = length(each.value.source_service_accounts) > 0 ? each.value.source_service_accounts : null
  target_tags             = length(each.value.target_tags) > 0 ? each.value.target_tags : null
  target_service_accounts = length(each.value.target_service_accounts) > 0 ? each.value.target_service_accounts : null

  dynamic "allow" {
    for_each = each.value.action == "allow" ? each.value.protocols : {}

    content {
      protocol = allow.key
      ports    = allow.value
    }
  }

  dynamic "deny" {
    for_each = each.value.action == "deny" ? each.value.protocols : {}

    content {
      protocol = deny.key
      ports    = deny.value
    }
  }

  log_config {
    metadata = var.firewall_log_metadata
  }
}
