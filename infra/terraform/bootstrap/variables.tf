variable "region" { type = string }
variable "project" { type = string }
variable "environment" { type = string }
variable "tenant_id" { type = string }
variable "connection_arn" {
  type        = string
  description = "Existing AVAILABLE CodeConnections ARN; authorize repository outside Terraform"
}
variable "repository_id" {
  type        = string
  description = "Provider full repository ID, e.g. owner/repository; no token or clone URL"
}
variable "branch" { type = string }
variable "enable_cloudtrail" {
  type        = bool
  default     = false
  description = "Create a management-event trail only if the account has no adequate existing trail"
}

variable "audit_account_is_dedicated" {
  type        = bool
  default     = false
  description = "Explicit confirmation required before collecting account-wide management events"
}
