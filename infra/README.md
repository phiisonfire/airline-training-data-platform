# Infrastructure

IMPLEMENTED trong repo: Terraform bootstrap/controller, tenant platform composition
và data_plane module. AWS deployment UNVERIFIED.

- [Bootstrap](terraform/bootstrap/main.tf): remote state/artifacts, CI roles/boundary,
  CodePipeline/CodeBuild và optional dedicated-account management audit.
- [Platform](terraform/platform/main.tf): một deployment/tenant/environment.
- [Data plane](terraform/modules/data_plane/main.tf): compute/storage/network/workflow;
  serving/monitoring trong cùng module.
- [CDK extension](cdk/README.md): input/output/artifact seam, chưa có CDK app.
- [Terraform guide](../docs/devops/terraform-and-cdk.md) và
  [deploy runbook](../docs/runbooks/devops-lab.md).

Chưa chọn account/Region/budget/isolation tier thật. Chỉ plan/apply trong authorization;
IaC code không phải bằng chứng resources đã tồn tại hoặc production-ready.
