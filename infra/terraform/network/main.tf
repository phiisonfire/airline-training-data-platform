terraform {
  required_version = ">= 1.14.6, < 2.0.0"
  backend "s3" {}
  required_providers {
    aws = { source = "hashicorp/aws", version = "= 5.100.0" }
  }
}
provider "aws" { region = var.region }
variable "region" { type = string }
variable "name" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,35}$", var.name))
    error_message = "Use the deployment prefix, e.g. atdp-dev-airline-a."
  }
}
variable "tenant_id" { type = string }
variable "network_cidr" {
  type        = string
  description = "Owner-selected unused canonical IPv4 /16 for one VPC; application/database/platform subnet groups. No CIDR default."
  validation {
    condition     = can(regex("^[0-9.]+/16$", var.network_cidr)) && can(cidrnetmask(var.network_cidr)) && try(cidrhost(var.network_cidr, 0) == split("/", var.network_cidr)[0], false)
    error_message = "Provide a canonical IPv4 /16, e.g. 10.80.0.0/16, checked against existing/customer networks."
  }
}
variable "availability_zones" {
  type = list(string)
  validation {
    condition     = length(var.availability_zones) == 2 && length(toset(var.availability_zones)) == 2
    error_message = "Select exactly two distinct AZs in the deployment Region."
  }
}
variable "sql_port" {
  type    = number
  default = 1433
  validation {
    condition     = var.sql_port >= 1 && var.sql_port <= 65535 && floor(var.sql_port) == var.sql_port
    error_message = "SQL port must be an integer between 1 and 65535."
  }
}
locals {
  groups = { application = 0, database = 1, platform = 2 }
  subnets = merge([for group, index in local.groups : {
    for az_index, az in var.availability_zones : "${group}-${az_index}" => {
      group = group, az = az, cidr = cidrsubnet(cidrsubnet(var.network_cidr, 4, index), 4, az_index)
    }
  }]...)
  tags = { Deployment = var.name, Tenant = var.tenant_id, ManagedBy = "terraform", Scope = "single-vpc-lab" }
}
resource "aws_vpc" "lab" {
  cidr_block           = var.network_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${var.name}-lab" })
}
resource "aws_subnet" "private" {
  for_each                = local.subnets
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false
  tags                    = merge(local.tags, { Name = "${var.name}-${each.key}" })
}
resource "aws_route_table" "private" {
  for_each = local.subnets
  vpc_id   = aws_vpc.lab.id
  tags     = merge(local.tags, { Name = "${var.name}-${each.key}" })
}
resource "aws_route_table_association" "private" {
  for_each       = local.subnets
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
resource "aws_security_group" "database_sql" {
  name_prefix = "${var.name}-database-sql-"
  description = "Attach to lab SQL host only; SQL ingress from platform worker subnets"
  vpc_id      = aws_vpc.lab.id
  tags        = local.tags
}
resource "aws_vpc_security_group_ingress_rule" "sql" {
  for_each          = { for k, v in local.subnets : k => v if v.group == "platform" }
  security_group_id = aws_security_group.database_sql.id
  cidr_ipv4         = each.value.cidr
  ip_protocol       = "tcp"
  from_port         = var.sql_port
  to_port           = var.sql_port
}
output "network_contract" {
  value = {
    contract_version               = "2"
    tenant_id                      = var.tenant_id
    vpc_id                         = aws_vpc.lab.id
    application_subnet_ids         = [for k, s in aws_subnet.private : s.id if local.subnets[k].group == "application"]
    database_subnet_ids            = [for k, s in aws_subnet.private : s.id if local.subnets[k].group == "database"]
    database_sql_security_group_id = aws_security_group.database_sql.id
    platform_inputs = {
      vpc_id          = aws_vpc.lab.id
      subnet_ids      = [for k, s in aws_subnet.private : s.id if local.subnets[k].group == "platform"]
      route_table_ids = [for k, rt in aws_route_table.private : rt.id if local.subnets[k].group == "platform"]
      sql_cidr        = cidrsubnet(var.network_cidr, 4, local.groups.database)
      sql_port        = var.sql_port
    }
  }
}
