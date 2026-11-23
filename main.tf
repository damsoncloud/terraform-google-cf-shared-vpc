locals {
  network_admins = "group:${var.network_admins_group_name}@${var.domain}"

  host_project_services = { for pair in setproduct(keys(var.host_projects), ["compute.googleapis.com"]) : "${pair[0]}/${pair[1]}" => {
    host    = pair[0]
    service = pair[1]
  } }

  network_admins_roles = { for pair in setproduct(keys(var.host_projects), ["roles/compute.networkAdmin", "roles/compute.securityAdmin"]) : "${pair[0]}/${pair[1]}" => {
    host = pair[0]
    role = pair[1]
  } }
}

resource "google_project_service" "host" {
  for_each = local.host_project_services

  project            = var.host_projects[each.value.host].project_id
  service            = each.value.service
  disable_on_destroy = false
}

resource "google_compute_shared_vpc_host_project" "host" {
  for_each = var.host_projects

  project = google_project_service.host["${each.key}/compute.googleapis.com"].project
}

resource "google_project_iam_member" "network_admins" {
  for_each = local.network_admins_roles

  project = google_compute_shared_vpc_host_project.host[each.value.host].project
  role    = each.value.role
  member  = local.network_admins
}
