# Damson Cloud GCP Cloud Foundations: Shared VPC

Terraform module of the Damson Cloud GCP Cloud Foundations configuring the Shared VPC of a Google Cloud organisation in its host projects, created by
[cf-organization](https://github.com/damsoncloud/terraform-google-cf-organization) in the common environment's folder: one for the environments in the VPC Service Controls
perimeter and one for the others, as a host project and its service projects must be in the same perimeter. It manages:

* the Shared VPC hosts, administered by the network administrators group,
* one VPC network per environment, in the host project of its environment, with its default routes replaced by an explicit route to the internet,
* a subnet per region, e.g. the primary and DR regions, with optional secondary ranges, Private Google Access and flow logs with all metadata,
* a Cloud Router with Cloud NAT per region, with logging,
* deny-by-default firewall rules, with administrative access through IAP.

## Usage

```hcl
module "shared_vpc" {
  source  = "damsoncloud/cf-shared-vpc/google"
  version = "X.Y.Z"

  domain        = "example.com"
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
    production = {
      host_project = "prod"
      subnets = {
        europe-west4 = { ip_cidr_range = "10.30.0.0/24" }
        europe-west1 = { ip_cidr_range = "10.30.1.0/24" }
      }
    }
  }
}
```

The resources are named after the environments' short names, e.g. `dev-vpc`, `dev-europe-west4-subnet` and `dev-internet-route`.

Pin an exact version. New versions are published as immutable GitHub releases with `vX.Y.Z` tags, following [semantic versioning](https://semver.org/).

<!-- BEGIN_TF_DOCS -->
<!-- markdownlint-capture -->
<!-- markdownlint-disable MD013 -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| domain | Domain of the organisation's groups. | `string` | n/a | yes |
| flow\_logs | VPC Flow Logs configuration of all the subnets:   `aggregation_interval`,   `flow_sampling` (0 to 1),   `metadata` (`INCLUDE_ALL_METADATA`, `EXCLUDE_ALL_METADATA` or `CUSTOM_METADATA`). | ```object({ aggregation_interval = optional(string, "INTERVAL_5_SEC") flow_sampling = optional(number, 0.5) metadata = optional(string, "INCLUDE_ALL_METADATA") })``` | `{}` | no |
| folders | The folders by folder name, e.g. the `folders` output of cf-hierarchy:   `id`, the resource name (`folders/<id>`);   `short_name`, the environment's short name, null for folders other than environments;   `common`, whether it is the common environment. The environments' short names prefix the names of their networks' resources. | ```map(object({ id = string short_name = optional(string) common = optional(bool, false) }))``` | n/a | yes |
| host\_projects | The Shared VPC host projects by name, e.g. the `shared_vpc_projects` output of cf-organization: `project_id`. A host project and its service projects must be in the same VPC Service Controls perimeter, so the environments inside and outside the perimeter have separate host projects. | ```map(object({ project_id = string }))``` | n/a | yes |
| network\_admins\_group\_name | Name of the group administering the networks, their firewall rules and external connectivity in the host projects, without the domain. | `string` | `"gcp-network-admins"` | no |
| networks | The VPC networks by environment name, one of the `folders` with a short name:   `host_project`, the name of its host project in `host_projects`, inside the perimeter for the environments in it;   `routing_mode`, `GLOBAL` or `REGIONAL`;   `subnets` by region, e.g. the primary and DR regions:     `ip_cidr_range`;     `secondary_ip_ranges`, CIDR ranges by range name, e.g. for GKE Pods and Services. | ```map(object({ host_project = string routing_mode = optional(string, "GLOBAL") subnets = map(object({ ip_cidr_range = string secondary_ip_ranges = optional(map(string), {}) })) }))``` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| host\_project\_ids | IDs of the Shared VPC host projects, enabled as hosts, by name, for cf-gcp-project's service projects. |
| networks | The VPC networks by environment name, for cf-gcp-project's service projects:   `id`, `name`, `self_link`;   `project_id` of the host project;   `subnets` by region:     `id`, `name`, `self_link`, `ip_cidr_range`;     `secondary_ip_ranges`, CIDR ranges by range name. |
<!-- markdownlint-restore -->
<!-- END_TF_DOCS -->

## Releases

Releases are dispatched manually on `main` with the [`release.yaml`](.github/workflows/release.yaml) workflow, choosing the part of the version to increase. It calls the
[`github-release.yaml`](https://github.com/damsoncloud/dcp.sdlc#reusable-workflows) reusable workflow, which creates the GitHub release and its tag. The Terraform Registry
publishes the new version from the tag.

## Security

See [SECURITY.md](SECURITY.md) for how to report vulnerabilities.

## Development

The repository uses [devenv](https://devenv.sh) with the shared [devenvbase](https://github.com/damsoncloud/dcp.sdlc/blob/main/devenvbase/README.md), pinned to a
[dcp.sdlc](https://github.com/damsoncloud/dcp.sdlc) release in `devenv.yaml`.

* `devenv shell` starts the shell.
* `devenv test` runs the git hooks and tests.
* `terraform_docs` regenerates the inputs and outputs above, which the `terraform-docs` git hook also does on commit.

The weekly `dcp.sdlc check` workflow opens an issue when a newer dcp.sdlc release is available. Upgrade with `devenv shell -- dcp_sdlc_upgrade_pr`, which also updates
the devenv inputs, runs the tests and opens a pull request.

## Licence

[Apache License 2.0](LICENSE)
