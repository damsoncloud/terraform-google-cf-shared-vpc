# Damson Cloud GCP Cloud Foundations: Shared VPC

Terraform module of the Damson Cloud GCP Cloud Foundations configuring the Shared VPC of a Google Cloud organisation in its host projects, created by
[cf-organization](https://github.com/damsoncloud/terraform-google-cf-organization) in the common environment's folder: one for the environments in the VPC Service Controls
perimeter and one for the others, as a host project and its service projects must be in the same perimeter. It manages:

* the Shared VPC hosts, administered by the network administrators group,
* one VPC network per environment,
* primary and DR region subnets with Private Google Access and flow logs,
* a Cloud Router with Cloud NAT per region, with logging,
* deny-by-default firewall rules, with administrative access through IAP.

## Usage

```hcl
module "shared_vpc" {
  source  = "damsoncloud/cf-shared-vpc/google"
  version = "X.Y.Z"

  domain        = "example.com"
  host_projects = module.organization.shared_vpc_projects
}
```

Pin an exact version. New versions are published as immutable GitHub releases with `vX.Y.Z` tags, following [semantic versioning](https://semver.org/).

<!-- BEGIN_TF_DOCS -->
<!-- markdownlint-capture -->
<!-- markdownlint-disable MD013 -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| domain | Domain of the organisation's groups. | `string` | n/a | yes |
| host\_projects | The Shared VPC host projects by name, e.g. the `shared_vpc_projects` output of cf-organization: `project_id`. A host project and its service projects must be in the same VPC Service Controls perimeter, so the environments inside and outside the perimeter have separate host projects. | ```map(object({ project_id = string }))``` | n/a | yes |
| network\_admins\_group\_name | Name of the group administering the networks, their firewall rules and external connectivity in the host projects, without the domain. | `string` | `"gcp-network-admins"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| host\_project\_ids | IDs of the Shared VPC host projects, enabled as hosts, by name, for cf-gcp-project's service projects. |
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
