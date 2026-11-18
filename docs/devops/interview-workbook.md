# Interview workbook — giải thích bằng code và failure evidence

Cách học: trả lời mỗi câu trong 60–90 giây, mở đúng file chứng minh thiết kế,
sau đó thực hiện drill. Không nói “đã chạy production” khi mới mock/local tests.

## 1. Hãy giới thiệu project này trong hai phút

Đây là AWS data platform lab tập trung DevOps. Business slice đọc full snapshot
một SQL Server test table, lưu raw, validate, mapping/filter và xuất S3 JSONL.
Infrastructure có tenant resource boundaries, secrets, network endpoints,
workflow/schedule, catalog/query, logs/alarms, remote state và release pipeline.
Tôi tách delivery workflow CodePipeline khỏi data workflow Step Functions.
Qualification/reporting đầy đủ là roadmap, không phải output hiện tại.

Minh họa: [architecture](architecture.md), `pipelines/sql_to_s3/job.py`, Terraform
`bootstrap` và `modules/data_plane`. Điểm khó là state/artifact/identity boundaries,
không phải đổi tên cột. Bằng chứng AWS thực tế cần bổ sung sau deployment.

## 2. CI và CD khác nhau thế nào trong project?

CI kiểm code/contracts/IaC, test behavior, audit dependencies và tạo immutable ZIP.
CD tính reviewed infrastructure plan, lấy approval, apply exact plan rồi verify
published artifact. Build xanh chưa chứng minh source connectivity hay data quality.

Drill: làm test mapping fail; chứng minh không có Plan/Apply stage sau Build failure.
Trong local, chạy pytest thay vì tự claim đã kiểm cloud stages.

## 3. Vì sao dùng CodePipeline và CodeBuild riêng?

CodePipeline điều phối stages/artifacts/approval; CodeBuild chạy commands trong
build environment. Tách build/plan/apply/verify roles giảm quyền một job và giúp
review/audit. Không cần long-lived AWS key hay GitHub OIDC khi dùng AWS service
roles. Trade-off: thêm managed services/cost và permissions cần vận hành.

Theo code: `infra/terraform/bootstrap/pipeline.tf`, `ci/codebuild/*.yml`.

## 4. Vì sao plan xong không chạy terraform apply theo config mới?

Config/state/variables/provider có thể đổi giữa review và apply. Saved binary plan
buộc apply proposed changes đã duyệt. Repo thêm source/ZIP/backend/boundary hashes
và TTL; không build lại artifact ở apply. Terraform cũng phát hiện một số stale
plan do state lineage/serial thay đổi. Hash không thay artifact access control.

Drill: `tests/infra/test_saved_plan.py` sửa source, plan bytes, boundary hoặc time;
assert subprocess không gọi apply. Đây là local behavioral evidence.

## 5. Terraform state chứa gì và vì sao nhạy cảm?

Resource IDs/attributes, outputs và ownership mapping. Có thể chứa sensitive values;
`sensitive=true` không mã hóa state. Vì vậy dùng S3 SSE-KMS/versioning, permission
scope theo key, không commit state. Password source nhập vào Secrets Manager ngoài
Terraform, code chỉ quản lý metadata/ARN.

Theo code: bootstrap state policies và source secret resource.

## 6. Lock giải quyết gì? Có bảo đảm exactly-once không?

S3 lockfile serialize state writers. Nó không khóa SQL/S3 business writes và không
chống manual AWS edits. QUEUED pipeline ngăn executions chồng trong controller này;
state lock vẫn cần cho writers khác. Data pipeline dùng immutable keys/raw replay,
không có distributed transaction SQL↔S3 và không claim exactly-once.

Drill: phân biệt lock timeout, stale saved plan và immutable-key conflict.

## 7. Plan role cần PutObject nhưng sao vẫn gọi là read-only plan?

Plan cần Put/Delete lockfile, không được ghi state chính hoặc mutate data-plane
resources. “Read-only” là đối với managed infrastructure, không phải zero writes.
Bootstrap operator khởi tạo remote state lần đầu; không nới plan role thành deploy
role chỉ để vượt qua initial backend setup.

Theo code: `aws_iam_role_policy.state` và `state_write`.

## 8. Permissions boundary khác IAM role policy và SCP thế nào?

Identity policy grant actions; boundary đặt ceiling cho role, không tự grant.
SCP đặt ceiling cấp organization/account; resource policy kiểm soát resource access.
Effective access phụ thuộc giao của applicable allows và explicit denies.
Repo bắt runtime roles có controller-owned boundary; apply role không sửa controller
IAM/boundary. Nhưng regional EC2 provisioning exceptions vẫn cần review thực tế.

Drill: chạy AWS negative tests sau deploy; mock HCL tests chưa chứng minh access.

## 9. Làm sao bảo vệ CI/CD khỏi privilege escalation?

Source branch protection, không cho untrusted PR dùng apply role, service trust
ràng buộc account/project, tách roles, approved saved plan, encrypted artifacts,
version/hash pinning. Controller IaC được bootstrap authority quản lý riêng.
Code review phải xem cả buildspec và IAM, không chỉ business code. Deploy role vẫn
privileged; không thể gọi đó là “an toàn tuyệt đối”.

Theo code: `bootstrap/deploy_permissions.tf`, `pipeline.tf`, `ci/iac.py`.

## 10. Tại sao Lambda thay vì Glue Spark/Airflow?

Một bounded table, bốn cột, vài validations không cần distributed compute. Lambda
giảm workload setup, Step Functions đủ điều phối hiện tại. Giới hạn: time/memory,
source size, connection budget và packaging. Nếu volume vượt bound hoặc transformations
cần distributed engine thì benchmark rồi đổi compute, giữ contracts/output semantics.
Không chọn Glue/EMR chỉ vì đây là data platform.

Drill: max_rows+1 phải fail chứ không silently truncate.

## 11. Lambda trong private subnet đọc SQL và AWS APIs thế nào?

Source SQL đi qua approved private route/DNS/SG, dùng SELECT-only credential và TLS
hostname validation. S3 qua gateway endpoint; Secrets qua private interface endpoint.
Không cần NAT chỉ cho hai APIs này. Endpoint có policy nhưng IAM/KMS vẫn phải allow.
Private subnet label không chứng minh route/connectivity; cần kiểm route table/AZ/DNS.

Theo code: data_plane SG/endpoints; `sources/sqlserver/extract.py`.

## 12. Secret rotation có tự hoạt động chưa?

Không. Job đọc secret ở mỗi extraction; chưa có rotation Lambda hoặc source-side
credential rotation workflow. Secret version được owner quản lý ngoài Terraform.
Retry đã có raw không cần SQL reread. Rotation cần source transaction/validation
và cutover design riêng, không chỉ bật một checkbox trong Secrets Manager.

## 13. Retry sau crash có làm dữ liệu thay đổi không?

Nếu raw đã durable, cùng run/binding dùng lại raw, không requery mutable source.
Conditional S3 writes cho cùng key/body là no-op; khác body conflict. Manifest viết
cuối. Crash trước raw commit có thể re-extract source mới; concurrent writers trước
raw commit có thể conflict. Đây là phạm vi guarantee, không exactly-once end-to-end.

Drill: `test_crash_after_data_before_manifest_reuses_raw` và immutable S3 tests.

## 14. DQ khác job failure và business failure thế nào?

Job/network error là technical failure; malformed source là DQ issue; một qualification
không đạt là business result. Slice chưa tính qualification. Nó giữ raw, quarantine
safe row indexes/codes và chặn publication khi contract invalid, kể cả inactive row.
Không sửa bad values để dashboard xanh.

Drill: source_id boolean, missing field, invalid date và duplicate PK.

## 15. Vì sao partition theo run_id? Có làm double-count không?

Mỗi output là full snapshot. Nếu quét mọi snapshots rồi SUM sẽ double-count.
Athena injected run_id buộc explicit run selection; consumer kiểm success manifest.
Manifest gate không được Athena enforce tự động. Đây là lab trade-off; production
có thể cần publication pointer/view/catalog promotion có concurrency design.

Theo code: `serving.tf`, snapshot contract và runbook SQL example.

## 16. Monitoring, logging và audit khác nhau thế nào?

Metrics trả lời tần suất/độ trễ/backlog; logs giải thích một execution; audit chứng
minh ai thay gì và data lineage. CloudWatch giữ worker/workflow/CI telemetry;
CloudTrail là AWS API audit, không thay raw/evaluation/delivery lineage.
Scheduler DLQ chỉ ghi dispatch failure, Lambda/business errors xem workflow/alarms.

Drill: mô phỏng DQ failure, invocation failure và scheduler dispatch failure;
chỉ claim AWS drill sau khi có run evidence.

## 17. Central logging có mâu thuẫn tenant isolation không?

Có nếu copy payload/PII vào shared log store. Repo centralize conventions/operational
view trong tenant deployment, không aggregate data-bearing logs giữa hãng.
Cross-account visibility vẫn là quyền truy cập cần approve; redaction trước emission,
retention/access riêng. SQL exceptions không log traceback/raw connection details.

Theo code: `handler.py`, encrypted log groups, execution-data logging=false.

## 18. Rollback khác recovery dữ liệu thế nào?

Rollback code deploy previous release qua reviewed plan; data recovery tái dựng từ
raw/state/backups với correct versions/as-of và tenant scope. Không xóa S3 để rollback
Lambda. Partial apply giữ state và re-plan; không destroy/recreate mù.

Drill: state-version restore và source replay là hai bài khác nhau; đều cần pause
writers, verify ownership và evidence trước khi tiếp tục.

## 19. Terraform và AWS CDK cùng dùng một resource được không?

Không nên có hai active owners. Future CDK adapter dùng same deployment/output
contracts và Lambda artifact nhưng state thuộc CloudFormation. Plan stage cần
immutable cloud assembly/change set, approval rồi execute exact change set.
Migration retain/import/ownership transfer được review riêng; không Terraform
destroy trước khi CDK tiếp quản data bucket.

Theo code: `ci/iac.py` hiện fail explicit nếu chọn CDK; không claim đã hỗ trợ runtime.

## 20. Nếu phỏng vấn hỏi “project production-ready chưa?”

Trả lời theo evidence: local behavior tests, Terraform schema/mock tests và package
build đã chạy; AWS deployment/SQL integration/access/recovery cần bằng chứng thật.
Thiếu numeric SLO, budget/isolation tier approvals, real source contract và full
reporting/backfeed acceptance. Nêu kế hoạch kiểm chứng từng gap, không dùng “đủ services”
làm bằng chứng production readiness.

## Self-assessment

Vẽ kiến trúc không nhìn docs; trace permission của một S3 write; giải thích một
failed saved-plan check; chỉ được resource ownership; thực hiện một local crash
replay; phân biệt mocked, integrated và deployed evidence. Sau đó bổ sung actual
AWS run IDs/cost measurements vào ghi chú cá nhân an toàn, không commit secrets.
