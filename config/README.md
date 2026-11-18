# Configuration

[Example](examples/devops-lab.json) có placeholders, intentionally không deploy được.
Copy sang `config/deployment.json`, điền non-secret account/network/source refs và
commit reviewed config cho CodePipeline. Schema từ chối password/unknown fields.

Tenant/state binding là trusted controller configuration; source event không đổi
routing. Credentials chỉ trong Secrets Manager ngoài Terraform. Custom business
policy contents thực tế không được copy vào shared control plane. AWS account/
Region/budget và isolation tier thật vẫn cần xác nhận.
