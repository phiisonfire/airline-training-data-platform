mock_provider "aws" {}
variables {
  region             = "us-east-1"
  name               = "atdp-dev-airline-a"
  tenant_id          = "airline-a"
  network_cidr       = "10.80.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
}
run "single_vpc_groups" {
  command = apply
  assert {
    condition     = aws_vpc.lab.cidr_block == "10.80.0.0/16" && alltrue([for s in aws_subnet.private : s.vpc_id == aws_vpc.lab.id])
    error_message = "Every subnet must belong to the single lab VPC."
  }
  assert {
    condition     = length(aws_subnet.private) == 6 && length(toset([for s in aws_subnet.private : s.cidr_block])) == 6 && alltrue([for s in aws_subnet.private : !s.map_public_ip_on_launch])
    error_message = "Three groups each need two distinct private subnets."
  }
  assert {
    condition     = aws_subnet.private["application-0"].cidr_block == "10.80.0.0/24" && aws_subnet.private["database-0"].cidr_block == "10.80.16.0/24" && aws_subnet.private["platform-0"].cidr_block == "10.80.32.0/24" && alltrue([for group in keys(local.groups) : aws_subnet.private["${group}-0"].availability_zone != aws_subnet.private["${group}-1"].availability_zone])
    error_message = "Application/database/platform CIDRs and AZ placement must remain separate."
  }
  assert {
    condition     = alltrue([for k, a in aws_route_table_association.private : a.subnet_id == aws_subnet.private[k].id && a.route_table_id == aws_route_table.private[k].id]) && alltrue([for rt in aws_route_table.private : rt.vpc_id == aws_vpc.lab.id])
    error_message = "Each subnet requires its own explicit same-VPC route table association."
  }
  assert {
    condition     = aws_security_group.database_sql.vpc_id == aws_vpc.lab.id && length(aws_vpc_security_group_ingress_rule.sql) == 2 && alltrue([for k, r in aws_vpc_security_group_ingress_rule.sql : r.cidr_ipv4 == local.subnets[k].cidr && local.subnets[k].group == "platform" && r.from_port == 1433 && r.to_port == 1433 && r.ip_protocol == "tcp"])
    error_message = "Database SQL may accept only SQL TCP from platform subnets, not application or Internet."
  }
  assert {
    condition     = output.network_contract.contract_version == "2" && output.network_contract.platform_inputs.subnet_ids == [aws_subnet.private["platform-0"].id, aws_subnet.private["platform-1"].id] && output.network_contract.database_subnet_ids == [aws_subnet.private["database-0"].id, aws_subnet.private["database-1"].id] && output.network_contract.application_subnet_ids == [aws_subnet.private["application-0"].id, aws_subnet.private["application-1"].id] && output.network_contract.platform_inputs.sql_cidr == "10.80.16.0/20"
    error_message = "Contract v2 must hand off correct subnet roles and database egress range."
  }
}
run "reject_noncanonical" {
  command = plan
  variables { network_cidr = "10.80.1.0/16" }
  expect_failures = [var.network_cidr]
}
run "reject_same_az" {
  command = plan
  variables { availability_zones = ["us-east-1a", "us-east-1a"] }
  expect_failures = [var.availability_zones]
}
run "custom_sql_port" {
  command = apply
  variables { sql_port = 1444 }
  assert {
    condition     = alltrue([for r in aws_vpc_security_group_ingress_rule.sql : r.from_port == 1444 && r.to_port == 1444]) && output.network_contract.platform_inputs.sql_port == 1444
    error_message = "SQL port must be consistent between database ingress and platform handoff."
  }
}
