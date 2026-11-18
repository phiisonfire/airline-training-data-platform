variable "name" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,35}$", var.name))
    error_message = "name must be a short lower-case resource prefix."
  }
}
variable "tenant_id" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,31}$", var.tenant_id))
    error_message = "Invalid trusted tenant binding."
  }
}
variable "lambda_zip" { type = string }
variable "release_id" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" {
  type = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Provide at least two existing private subnets."
  }
}
variable "route_table_ids" {
  type = list(string)
  validation {
    condition     = length(var.route_table_ids) > 0
    error_message = "Provide route tables for the S3 gateway endpoint."
  }
}
variable "sql_cidr" {
  type = string
  validation {
    condition     = can(cidrhost(var.sql_cidr, 0)) && var.sql_cidr != "0.0.0.0/0"
    error_message = "SQL egress needs an explicit source network, not all IPv4."
  }
}
variable "sql_port" {
  type    = number
  default = 1433
}
variable "source_schema" {
  type    = string
  default = "devops"
}
variable "source_table" {
  type    = string
  default = "pilot_source"
}
variable "max_rows" {
  type    = number
  default = 10000
}
variable "retention_days" {
  type = number
  validation {
    condition     = var.retention_days >= 1 && floor(var.retention_days) == var.retention_days
    error_message = "Retention must be an explicitly selected positive day count."
  }
}
variable "schedule_expression" {
  type    = string
  default = "rate(1 day)"
}
variable "schedule_enabled" {
  type    = bool
  default = false
}
variable "tags" { type = map(string) }

variable "runtime_boundary_arn" { type = string }
