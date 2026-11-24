module "hierarchy" {
  source  = "damsoncloud/cf-hierarchy/google"
  version = "0.2.0"

  organization_id = var.organization_id
}

module "bootstrap" {
  source  = "damsoncloud/cf-bootstrap/google"
  version = "0.8.0"

  organization_id = var.organization_id
  folders         = module.hierarchy.folders
  billing_account = var.billing_account
}

module "organization" {
  source  = "damsoncloud/cf-organization/google"
  version = "0.5.0"

  organization_id     = var.organization_id
  domain              = var.domain
  environment_tag_key = module.hierarchy.environment_tag_key_namespaced_name
  folders             = module.hierarchy.folders
  billing_account     = var.billing_account

  bootstrap_project_id            = module.bootstrap.project_id
  tf_bootstrap_email              = module.bootstrap.tf_bootstrap_email
  tf_bootstrap_organization_roles = module.bootstrap.tf_bootstrap_organization_roles
  tf_plan_email                   = module.bootstrap.tf_plan_email
  tf_plan_organization_roles      = module.bootstrap.tf_plan_organization_roles
  tf_environment_emails           = module.bootstrap.tf_environment_emails

  shared_vpc = {
    host_projects = {
      prod    = { budget_amount = 200 }
      nonprod = {}
    }
  }
  # The network administrators administer the host project in the perimeter from outside it
  perimeter_groups = {
    organization = ["gcp-organization-admins", "gcp-network-admins"]
  }
}

module "org_policies" {
  source  = "damsoncloud/cf-organization/google//modules/org-policies"
  version = "0.5.0"

  organization_id           = var.organization_id
  mode                      = var.mode
  allowed_locations         = ["in:europe-west4-locations", "in:europe-west1-locations"]
  shared_vpc_host_folder_id = module.hierarchy.folders["common"].id
}

module "vpc_service_controls" {
  source  = "damsoncloud/cf-organization/google//modules/vpc-service-controls"
  version = "0.5.0"

  organization_id = var.organization_id
  mode            = var.mode
  projects = {
    bootstrap      = module.bootstrap.project_number
    observability  = module.organization.observability_project_number
    api_management = module.organization.api_management_project_number
    # The host project of the environments in the perimeter; the other host project stays outside it
    shared_vpc_prod = module.organization.shared_vpc_projects["prod"].number
  }
  deployers = concat(
    [module.bootstrap.tf_bootstrap_email, module.bootstrap.tf_plan_email],
    values(module.bootstrap.tf_environment_emails),
  )
  groups = module.organization.perimeter_groups
}

module "shared_vpc" {
  source = "../.."

  domain        = var.domain
  folders       = module.hierarchy.folders
  host_projects = module.organization.shared_vpc_projects

  flow_logs = {
    aggregation_interval = "INTERVAL_30_SEC"
    flow_sampling        = 0.25
  }
  cloud_nat = {
    log_filter                     = "TRANSLATIONS_ONLY"
    enable_dynamic_port_allocation = true
    min_ports_per_vm               = 64
    max_ports_per_vm               = 4096
  }

  networks = {
    development = {
      host_project = "nonprod"
      subnets = {
        europe-west4 = { ip_cidr_range = "10.10.0.0/24" }
      }
    }
    certification = {
      host_project = "nonprod"
      cloud_nat    = { enabled = false }
      iap_ports    = ["22"]
      subnets = {
        europe-west4 = { ip_cidr_range = "10.20.0.0/24" }
      }
    }
    production = {
      host_project = "prod"
      # Static NAT IP addresses, allowlisted by third parties
      cloud_nat = { ip_allocation = "MANUAL_ONLY", ip_address_count = 2 }
      iap_ports = ["22"]
      subnets = {
        europe-west4 = {
          ip_cidr_range       = "10.30.0.0/22"
          secondary_ip_ranges = { gke-pods = "10.130.0.0/16", gke-services = "10.131.0.0/20" }
        }
        europe-west1 = { ip_cidr_range = "10.30.4.0/22" }
      }
      firewall_rules = {
        allow-lb-health-checks = {
          description = "Load balancer health checks"
          ranges      = ["35.191.0.0/16", "130.211.0.0/22"]
          target_tags = ["web"]
          protocols   = { tcp = ["443"] }
        }
        allow-web-to-db = {
          description = "PostgreSQL from the web tier"
          source_tags = ["web"]
          target_tags = ["db"]
          protocols   = { tcp = ["5432"] }
        }
        deny-smtp-egress = {
          direction = "EGRESS"
          action    = "deny"
          ranges    = ["0.0.0.0/0"]
          protocols = { tcp = ["25"] }
        }
      }
    }
  }
}
