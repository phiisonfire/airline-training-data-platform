terraform {
  required_version = ">= 1.14.6, < 2.0.0"
  backend "s3" {}
  required_providers {
    aws = { source = "hashicorp/aws", version = "= 5.100.0" }
  }
}
variable "deployment" {
  description = "Generated from the IaC-neutral deployment contract, no credentials"
  type = object({
    project             = string, environment = string, tenant_id = string, region = string,
    vpc_id              = string, subnet_ids = list(string), route_table_ids = list(string),
    sql_cidr            = string, sql_port = number, source_schema = string, source_table = string,
    retention_days      = number, max_rows = number, schedule_enabled = bool,
    schedule_expression = string, release_id = string, runtime_boundary_arn = string
  })
}
provider "aws" {
  region = var.deployment.region
  default_tags {
    tags = { Project = var.deployment.project, Environment = var.deployment.environment,
    Tenant = var.deployment.tenant_id, Deployment = "${var.deployment.project}-${var.deployment.environment}-${var.deployment.tenant_id}", ManagedBy = "terraform", Owner = "lab-platform-engineer" }
  }
}
module "data_plane" {
  source               = "../modules/data_plane"
  name                 = "${var.deployment.project}-${var.deployment.environment}-${var.deployment.tenant_id}"
  runtime_boundary_arn = var.deployment.runtime_boundary_arn
  tenant_id            = var.deployment.tenant_id
  release_id           = var.deployment.release_id
  lambda_zip           = "${path.root}/../../../build/lambda.zip"
  vpc_id               = var.deployment.vpc_id
  subnet_ids           = var.deployment.subnet_ids
  route_table_ids      = var.deployment.route_table_ids
  sql_cidr             = var.deployment.sql_cidr
  sql_port             = var.deployment.sql_port
  source_schema        = var.deployment.source_schema
  source_table         = var.deployment.source_table
  retention_days       = var.deployment.retention_days
  max_rows             = var.deployment.max_rows
  schedule_enabled     = var.deployment.schedule_enabled
  schedule_expression  = var.deployment.schedule_expression
  tags = { Project = var.deployment.project, Environment = var.deployment.environment,
  Tenant = var.deployment.tenant_id, Deployment = "${var.deployment.project}-${var.deployment.environment}-${var.deployment.tenant_id}", ManagedBy = "terraform", Owner = "lab-platform-engineer" }
}
output "deployment_contract" { value = module.data_plane.deployment_contract }
