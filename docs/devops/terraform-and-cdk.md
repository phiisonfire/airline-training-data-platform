# Terraform: thực hành và mở rộng AWS CDK

## Root modules và state boundaries

`infra/terraform/bootstrap`: state/artifacts KMS/S3, runtime permissions boundary,
CodeBuild roles/projects/logs, CodePipeline và optional management CloudTrail.
Initial bootstrap dùng local state bảo vệ ngoài Git; sau đó migrate lên S3 bằng
backend riêng. Root này chỉ operator có quyền bootstrap chạy, không tự CI apply.

`infra/terraform/platform`: một deployment/tenant/environment dùng module
`modules/data_plane`. Một state key `platform/<project>-<env>-<tenant>/terraform.tfstate`.
Không dùng Terraform workspaces làm tenant security boundary. Dev/test/prod khác
config/state; strict tier có thể khác AWS account và deployment credentials.

State là mapping resource address ↔ remote identity và computed attributes; không
chỉ là cache. Mất state không có nghĩa mất resources nhưng apply thiếu state có
thể tạo trùng/conflict. `sensitive=true` chỉ che UI output, không xóa secret khỏi
state. Vì vậy repo chỉ tạo secret metadata, không khai báo secret value resource.

## State backend và locking

S3 backend dùng versioning, SSE-KMS và `use_lockfile=true`. Plan role cần đọc
state, tạo/đọc/xóa `.tflock`; chỉ apply role được ghi state object. Lock chống
simultaneous state writers, không khóa SQL source hay các manual AWS console edits.
QUEUED CodePipeline giảm chạy chồng cùng state nhưng không thay lock.

Backend configuration không đặt trong deployment variable vì Terraform init xảy
ra trước graph evaluation. CI truyền backend bindings từ protected CodeBuild
project environment; state key phải khớp deployment identity. Không cho source
config chọn arbitrary backend/state key.

`force-unlock` chỉ sau khi xác minh không có process giữ lock; không xóa lock để
“sửa nhanh” trong khi apply còn chạy. State version restore cần đối chiếu actual
resources và khóa writers trước; không restore version cũ rồi apply ngay.

Xem [S3 backend docs](https://developer.hashicorp.com/terraform/language/backend/s3).

## Plan, apply và drift

`plan -out=tfplan` tạo binary chứa proposed changes và context; coi plan/state là
sensitive artifact. `show tfplan` dùng review, không phải file để apply. Pipeline
apply chính binary đã duyệt; không chạy `terraform apply` để tạo plan khác.

Repo bind plan vào source tree hash, Lambda SHA256, backend key, runtime boundary,
creation time và binary plan SHA256. Quá 24h hoặc khác inputs → fail, cần re-plan.
Terraform cũng có stale saved-plan checks dựa state lineage/serial. Hash checks
không thay artifact bucket IAM/KMS hoặc code review của privileged pipeline.

Drift review: owner chạy plan qua pipeline định kỳ/manual; chưa có automatic
scheduled drift detection. Manual edit Lambda alias rồi plan sẽ thấy desired
state khác; chọn revert hay update code, không apply mù.

Lab buckets không dùng `prevent_destroy`, dùng `force_destroy=true`: destroy xóa
cả objects/versions. Secret không có recovery window; KMS chờ xóa 7 ngày.
Đây là destructive lab defaults, không dùng nguyên trạng cho production.
Xem [cleanup runbook](../runbooks/devops-lab-cleanup.md) trước destroy, đặc biệt
apply flags vào existing state và migrate bootstrap backend về local trước khi
xóa state bucket.

## Pinning và modules

Terraform CLI pinned trong `ci/terraform-version.json`; installer xác minh SHA256.
Provider pinned trong versions/root files và `.terraform.lock.hcl` được commit.
Module hiện local, không có unpinned registry dependency. Khi update version: branch
riêng → lock update → fmt/validate/mock tests → reviewed real plan. Pinning không
có nghĩa bỏ qua security updates.

Không parameterize mọi thuộc tính AWS. Inputs hiện phục vụ tenant/network/source
binding và lab policies; thêm option khi có use case. Outputs là deployment contract
v1, cho CI/consumers biết resources mà không hardcode Terraform addresses.

## CDK extension seam

Dùng **AWS CDK**, không yêu cầu CDK for Terraform. Hiện CDK chưa implement; CLI
nhận engine selection nhưng fail rõ ràng khi `iac_engine=cdk`.

Dùng chung khi thêm CDK:

1. `contracts/devops/deployment.schema.json`: deployment inputs không chứa HCL.
2. Lambda ZIP + release hash, SQL/source/data contract, Python tests.
3. Step Functions semantics, governance/observability expectations và deployment
   output contract v1 (định nghĩa đầy đủ trong Terraform module outputs).
4. CI interface validate → plan → approve → apply → verify.

Khác implementation:

| Operation | Terraform hôm nay | CDK implementation sau này |
|---|---|---|
| Validate | fmt/validate/mock tests | Typecheck/unit tests/CDK synth assertions |
| Plan | Saved tfplan | Synth immutable cloud assembly, tạo CloudFormation change set |
| Approve | Review tfplan/source/release | Review exact change set và synthesized template |
| Apply | Apply saved tfplan | Execute đúng change set đã duyệt, không synth/deploy lại tùy ý |
| State | S3 state + lock | CloudFormation stacks, events và resource ownership |

Mỗi resource chỉ một IaC owner. Không chạy Terraform và CDK tạo cùng buckets/roles.
Thử CDK ở environment khác trước. Migration thật cần resource support matrix,
retain/import plan, transfer ownership có review, rollback/recovery và tenant
negative tests. Không mặc định terraform destroy để “chuyển CDK”.

[AWS CDK guide](https://docs.aws.amazon.com/cdk/v2/guide/home.html) là nguồn tham
chiếu khi triển khai adapter; không coi extension plan này là CDK runtime đã có.
