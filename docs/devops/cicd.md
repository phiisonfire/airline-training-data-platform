# CodePipeline / CodeBuild release flow

## Một commit đi qua pipeline thế nào?

1. **Source**: CodeCommit repository có sẵn trong cùng account/Region, branch đã push.
   Bootstrap nhận `repository_name` và `branch`; không dùng CodeConnection/Git token.
   `PollForSourceChanges=true` phát hiện commit bằng polling; chưa dùng EventBridge.
   Source xuất CODE_ZIP; CodeBuild không cần quyền GitPull. Pipeline role chỉ có
   GetBranch/GetCommit/UploadArchive/GetUploadArchiveStatus/CancelUploadArchive
   trên ARN repository đã chọn. Repository do operator quản lý ngoài bootstrap.
2. **Build**: install hashed lockfile, package Linux x86_64 Python 3.12 ZIP,
   lint/tests, Terraform schema/mock-provider tests, dependency audit và validate
   deployment config. Không có quyền deploy hoặc đọc source SQL secret.
3. **Plan**: dùng BuildOutput, immutable ZIP và provider locks; refresh actual
   resources, acquire state lock, xuất tfplan/tfplan.txt/metadata.json vào PlanOutput.
4. **Approval**: người có quyền review đọc source revision, plan text, scope/cost,
   destructive changes và release hash. Manual approval nằm ở CodePipeline,
   không phải `input()` hoặc `sleep` trong CodeBuild.
5. **Apply**: nhận chính BuildOutput + PlanOutput, kiểm binding/hash/age, init đúng
   backend và apply binary. Không build lại Lambda hoặc tính plan mới.
6. **Verify**: Describe live Lambda/workflow và so Lambda CodeSha256 với release;
   báo secret có version chưa. Không tự đọc secret, chạy SQL hoặc tuyên bố data
   correctness. Smoke nguồn thật là bước operator chạy có kiểm soát sau setup.

CI definitions: `ci/codebuild/{build,plan,apply,verify}.yml`;
controller resources: `infra/terraform/bootstrap/pipeline.tf`.

## Trust và quyền

Không dùng access keys dài hạn cho CodeBuild. AWS service roles cung cấp temporary
credentials. Không cần GitHub Actions/OIDC cho lựa chọn CodePipeline này.
CodeBuild trust ràng buộc SourceAccount + project SourceArn. Source branch phải
được bảo vệ; không đưa untrusted pull request vào jobs có AWS mutation authority.
Không có PR webhook runner trong baseline; PR authors chạy checks local hoặc
thêm unprivileged CI project riêng trước khi mở rộng.

| Role | Được làm | Không được làm |
|---|---|---|
| Build | Artifact reads/writes, build logs, control KMS | Deploy resources, đọc SQL secret |
| Plan | Build permissions + resource metadata refresh + state read/lock | State object write, source secret read, resource mutations |
| Apply | State write + named data-plane resource provisioning | Chỉnh controller IAM, bỏ runtime boundary, đọc source secret/data objects |
| Verify | Resource metadata reads | Deploy/start SQL pipeline/read source secret |
| Worker | Tenant raw/curated/quarantine writes, secret read, tenant KMS, logs/VPC ENI | Chọn arbitrary tenant/target hoặc đọc tenant khác |

Runtime permissions boundary đặt ceiling; identity policy vẫn phải allow. Boundary
không grant quyền và không thay SCP/resource policies. Deploy role có regional
EC2 exceptions và KMS/resource provisioning authority cần security review trong
account thật. Mock tests không chứng minh tất cả service authorization paths.

## Artifacts và supply chain

- Runtime/dev dependencies có version + hashes; `pip-audit` là networked security
  gate trong Build, không phải default local pytest. Advisory outage làm gate fail.
- Terraform binary SHA256 pinned; AWS provider lock có checksums.
- ZIP chứa native crypto wheels dành Linux x86_64/AL2023 glibc, không copy venv
  Windows/WSL làm Lambda artifact. No Docker privileged mode needed.
- Binary plan/state có thể chứa sensitive metadata; encrypted artifact bucket,
  restricted access, 7-day expiry. Không upload plan vào public PR comments.
- Hash/source binding phát hiện nhầm artifact, không thay chữ ký/attestation và
  permissions. Dependency mirror/SBOM/signing có thể thêm khi có nhu cầu.
- Apply artifacts chỉ giữ deployment output metadata, không xuất Terraform state.

## Promotion, rollback và failure handling

Baseline có một controller/tenant/environment. Promote sang test/prod bằng cùng
source revision/artifact design, config/state/account riêng, approval riêng; chưa
có multi-account promotion pipeline. Không tự create production.

Build failure → sửa code/locks; Plan failure → xác minh IAM/config/drift; rejected
approval → không apply; stale plan → execution mới; apply partial failure → giữ
state, inspect failed resources rồi re-plan, không xóa state để retry.
Verify failure xảy ra sau apply: infrastructure có thể đã đổi; operator investigate,
không tự destroy. Rollback code bằng previous reviewed release qua plan/apply;
raw/curated snapshots không bị “rollback code” xóa. `live` alias không có canary
traffic shifting trong baseline; version history không thay data recovery.

Một CodePipeline success chỉ chứng minh gates tương ứng đã pass, chưa chứng minh
SQL data đầy đủ, source freshness hoặc toàn bộ airline platform hoạt động.

Tham khảo [AWS sample Terraform pipeline](https://github.com/aws-samples/terraform-aws-pipeline)
và [CodeBuild runtimes](https://docs.aws.amazon.com/codebuild/latest/userguide/available-runtimes.html).
