# AWS CDK extension boundary

Chưa có CDK app/dependencies/resources. `iac_engine=cdk` fail explicit trong CLI.

Khi triển khai: dùng input schema `contracts/devops/deployment.schema.json`, cùng
Lambda artifact/hash, output contract v1 và acceptance semantics. Thêm CDK tests,
immutable cloud assembly + reviewed CloudFormation change set flow; không chỉ
thay `terraform apply` bằng `cdk deploy` sau approval rồi synth lại.

Không có dual resource ownership. Thử ở environment riêng; migration production
cần retain/import/ownership plan và rollback/data recovery. Xem
[Terraform/CDK guide](../../docs/devops/terraform-and-cdk.md).
