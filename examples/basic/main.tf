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

  shared_vpc = {}
}

module "shared_vpc" {
  source = "../.."

  domain        = var.domain
  folders       = module.hierarchy.folders
  host_projects = module.organization.shared_vpc_projects

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
      subnets = {
        europe-west4 = { ip_cidr_range = "10.20.0.0/24" }
        europe-west1 = { ip_cidr_range = "10.20.1.0/24" }
      }
    }
    production = {
      host_project = "prod"
      subnets = {
        europe-west4 = { ip_cidr_range = "10.30.0.0/24" }
        europe-west1 = { ip_cidr_range = "10.30.1.0/24" }
      }
    }
  }
}
