# Configuration

[Example](examples/devops-lab.json) có placeholders, intentionally không deploy được.
Copy sang `config/deployment.json`, điền non-secret account/network/source refs và
commit reviewed config cho CodePipeline. Schema từ chối password/unknown fields.

Tenant/state binding là trusted controller configuration; source event không đổi
routing. Credentials chỉ trong Secrets Manager ngoài Terraform. Custom business
policy contents thực tế không được copy vào shared control plane. AWS account/
Region/budget và isolation tier thật vẫn cần xác nhận.

## Một VPC, ba subnet groups

Operator root `infra/terraform/network` tạo một lab VPC, application/database/
platform private subnets ở hai AZ và SQL SG. Output network_contract v2 chứa
application_subnet_ids, database_subnet_ids, database_sql_security_group_id và
platform_inputs. Copy CHỈ platform_inputs vào deployment.json (schema vẫn v1).
`vpc_id` là shared VPC; `subnet_ids`/`route_table_ids` chỉ platform group, `sql_cidr`
là database range. Source host/app do owner quản lý ngoài network root. Không
peering hoặc independent customer/provider network boundary; subnet separation
không thay SG/IAM/SQL permissions hoặc tenant isolation.
Xem [single-VPC runbook](../docs/runbooks/single-vpc-lab.md).
