variable "organization_id" {
  description = "ID of the organisation."
  type        = string
}

variable "domain" {
  description = "Domain of the organisation's groups."
  type        = string
}

variable "billing_account" {
  description = "ID of the billing account."
  type        = string
}

variable "mode" {
  description = "Mode of the organisation policies and the perimeter: `dry_run` first, then `enforced`."
  type        = string
  default     = "dry_run"
}
