variable "region" { type = string }
variable "project" { type = string }
variable "environment" { type = string }
variable "tenant_id" { type = string }
variable "repository_name" {
  type        = string
  description = "Existing CodeCommit repository in the deployment account and Region; push the selected branch before bootstrap apply"
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]{1,100}$", var.repository_name))
    error_message = "Use a CodeCommit repository name, not an owner/repository path, ARN or URL."
  }
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
