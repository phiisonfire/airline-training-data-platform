# DevOps lab — setup, deploy, verify và recovery

Ngày: 2026-11-18. Các lệnh deploy dưới đây là runbook cho operator, chưa phải
bằng chứng đã chạy AWS. Chỉ apply sau khi xác nhận account/Region/budget/network
và reviewed plan. Không có remote resources được tạo khi soạn repo này.

## 1. Local learning, không cần AWS credentials

Prerequisites: Linux x86_64/WSL, Python 3.12 + pip. Tạo venv, install locked dev
requirements; có thể dùng uv thay cho pip nhưng giữ lock/hash verification.

```bash
python3.12 -m venv .venv
.venv/bin/python -m pip install --require-hashes -r requirements-dev.lock
.venv/bin/python ci/install_terraform.py
.venv/bin/python -m ruff check .
.venv/bin/python -m pytest -q
.venv/bin/python -m ci.local_demo
.venv/bin/python ci/package.py
.venv/bin/python ci/check_package.py
.venv/bin/python ci/check.py
```

Default `ci/check.py` gồm mock Terraform tests, không cần AWS login/resources.
Provider init và package dependency install cần Internet; Terraform provider
cần được phép mở local plugin socket. `pip-audit` là gate riêng cần advisory API:

```bash
.venv/bin/python -m pip_audit -r requirements.lock --no-deps --disable-pip
```

Offline demo ở `build/local/`, ZIP/hash ở `build/`; đều Git-ignored. Demo không
kiểm chứng SQL, IAM, AWS routing hoặc Lambda runtime. Tests dùng explicit dates,
synthetic identifiers và fake AWS clients, không production.

## 2. Quyết định trước AWS apply

Ghi lại: AWS account/Region, lab budget/cleanup owner, tenant isolation tier,
existing VPC/private subnet IDs, route table IDs, SQL CIDR/port/DNS/TLS trust,
read-only SQL principal, existing org/account CloudTrail coverage và CodeCommit repository name/branch trong cùng account/Region. Không tự mở SQL public Internet để test.

Interface endpoint Secrets Manager và S3 gateway endpoint được module tạo. Nếu
VPC đã có endpoints, xem plan và quyết định import/reuse trước apply; không tự
sửa shared route tables. VPC phải hỗ trợ endpoint private DNS. Chọn subnets ở ít
nhất hai AZ khi có thể; Terraform hiện chỉ check cùng VPC/no auto public IP,
operator phải xác minh AZ, private routing và source reachability.

Initial deployment dùng một tenant/environment. Tạo controller/state/data plane
riêng cho tenant khác; dedicated account tier cần account bindings/principals
riêng và negative-access drill, không chỉ đổi tenant_id trong một shared state.

## 3. Chuẩn bị reviewed configuration

Copy `config/examples/devops-lab.json` sang `config/deployment.json`; thay toàn bộ
REPLACE values, review source/network/retention. File JSON **không chứa secrets**
và cần commit để CodeBuild source artifact có config. Schema từ chối fields lạ
như password. Ví dụ retention 30 ngày chỉ là lab proposal, không production policy.

```bash
.venv/bin/python ci/iac.py validate
```

Source dùng CodeCommit repository có sẵn trong cùng account/Region. Operator tạo
repository và push branch đã review trước bootstrap apply; bootstrap không tạo repo.
Điền `repository_name` (tên repo, không phải URL hoặc owner/repository) và `branch`.
Không cần `connection_arn`/`repository_id`; xóa các inputs cũ khỏi tfvars nếu đã có.
Polling có thể khởi chạy CI; platform Apply vẫn cần manual approval.

Bootstrap variables: copy `infra/terraform/bootstrap/terraform.tfvars.example`
thành `terraform.tfvars` trong cùng thư mục, điền non-secret references. `.tfvars`
và state/plan bị Git-ignore. CLI dùng profile/role đã được owner cho phép; không
đưa access keys vào HCL hoặc source config.

## 4. Bootstrap controller một lần

Dùng bootstrap authority riêng, không deploy role của platform. Đây là bước có
phí sau approval. Không có config account thực tế trong repo.

```bash
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap init
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap plan -out=bootstrap.tfplan
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap show bootstrap.tfplan
# Sau khi owner duyệt đúng plan:
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap apply bootstrap.tfplan
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap output -json bootstrap_contract
```

Local bootstrap state chứa sensitive infrastructure metadata: giữ encrypted và
restricted ngoài Git, không upload công khai. Sau first apply, tạo file ignored
`infra/terraform/bootstrap/backend.tf` với `terraform { backend "s3" {} }`, migrate
state vào bucket state vừa tạo, key riêng `bootstrap/<deployment>/terraform.tfstate`:

```bash
/tmp/atdp-tools/terraform -chdir=infra/terraform/bootstrap init -migrate-state \
  -backend-config=bucket=YOUR_STATE_BUCKET \
  -backend-config=key=bootstrap/YOUR_DEPLOYMENT/terraform.tfstate \
  -backend-config=region=YOUR_REGION \
  -backend-config=kms_key_id=YOUR_CONTROL_KMS_ARN \
  -backend-config=encrypt=true \
  -backend-config=use_lockfile=true
```

Giữ bootstrap backend binding an toàn để operator/CI checks không nhầm local
state về sau. Không commit `.terraform/` metadata. Bootstrap role quản lý backend
riêng; platform plan/apply roles không có quyền bootstrap state key.

Pipeline CodeCommit polling bật; trước bootstrap apply phải có config và
source branch đã review. Pipeline có manual approval, không auto apply platform.
Chỉ người được cấp `codepipeline:PutApprovalResult` nên được approve. Không tạo
human notification subscriptions trong baseline; operator xem console.

Trước lần Plan đầu tiên, bootstrap operator khởi tạo **empty platform backend**
bằng quyền owner. Plan role không được tạo/ghi initial state object. Script dưới
chỉ seed output metadata, không tạo data-plane resources; refuse nếu object đã
có hoặc saved plan chứa resource changes/drift. Không chạy script để reset state.
Dùng key từ bootstrap output, không dùng bootstrap state key:

```bash
.venv/bin/python ci/initialize_state.py \
  --bucket YOUR_STATE_BUCKET \
  --key platform/YOUR_DEPLOYMENT/terraform.tfstate \
  --region YOUR_REGION \
  --kms-arn YOUR_CONTROL_KMS_ARN
```

Script này ghi remote state, chỉ chạy khi operator đã được phép. Nó dùng root
configuration tạm thời không có resources; sau đó platform root tiếp quản cùng
state và thay initialization output bằng deployment outputs. Không viết JSON
state bằng tay hoặc cấp state-write cho plan role để bỏ qua bootstrap.

## 5. First platform release

Trong CodePipeline: kiểm Build → xem encrypted PlanOutput `tfplan.txt` +
`metadata.json` → review costs/IAM/endpoints/source revision → approve. Plan
chỉ hợp lệ 24h; hết hạn thì execution mới, không sửa metadata timestamp.
Apply dùng exact binary, Verify so published Lambda hash/workflow state.

`Verify` báo secret có version chưa nhưng không query SQL. Chưa có secret version
vẫn có thể deploy thành công; data readiness là bước kế tiếp. CodePipeline success
không phải pipeline data success.

## 6. Provision source và controlled data smoke

Source owner áp dụng `tests/fixtures/pilot_source.sql` vào SQL Server TEST, cấp
SELECT-only table cho principal riêng; không chạy fixture trên production.
SQL secret JSON schema: đúng 6 fields `tenant_id`, `host`, `port` (integer),
`database`, `username`, `password`. Nhập bằng Secrets Manager console/approved
secret tooling vào ARN từ deployment output. Không lưu password vào Terraform,
state, source config, shell history hoặc CI logs.

Driver luôn TLS + hostname validation, full-session encryption. Baseline trust
là certifi CAs. Private corporate CA cần bổ sung public CA bundle vào artifact
và reviewed `SQL_CA_FILE` environment wiring; không disable validation. Private
CA bundle customization chưa nằm trong deployment schema v1.

Sau khi source/network/secret ready, operator được ủy quyền start Step Functions
execution với tên duy nhất chỉ gồm letters/numbers/underscore/hyphen, tối đa 80.
Workflow tự lấy tên đó làm run_id; input không chọn tenant/SQL/bucket.

Expected fixture result: raw 2 rows; curated 1 row pilot_id=1; filtered_count=1;
manifest có matching SHA256 và release/binding. Kiểm manifest success trước query:

```sql
SELECT tenant_id, pilot_id, pilot_name, employment_date
FROM your_catalog_database.pilot_snapshot
WHERE run_id = 'your_successful_execution_name';
```

Không query nhiều run_ids rồi cộng snapshots. Athena run_id projection yêu cầu
explicit run filter; manifest gate vẫn do consumer/operator thực hiện.
Schedule chỉ enable qua reviewed config/plan sau smoke. `rate(1 day)` là lab
schedule, không nghiệm thu reporting deadline hay backfeed SLA.

## 7. Failure drills và recovery

| Drill | Quan sát và hành động |
|---|---|
| SQL unreachable/TLS mismatch | Safe technical error, no manifest; sửa route/trust/source, không tắt TLS |
| Secret tenant mismatch | Fail trước SQL connect; sửa trusted binding, không fallback tenant |
| Bad type/duplicate row | Raw + quarantine, no curated/manifest; fix source, chạy run mới |
| Crash sau raw trước data/manifest | Redrive execution giữ run_id/release; dùng committed raw, không query SQL lại |
| Same run khác release/binding | Fail conflict; chọn run_id mới; không overwrite historical raw |
| Snapshot >max_rows | Fail, không truncate; tăng limit chỉ sau memory/time benchmark hoặc đổi compute |
| Saved plan quá hạn/khác source | Không apply; tạo plan mới và review lại |
| Partial Terraform apply | Pause pipeline, giữ state, inspect resources, reviewed re-plan; không delete state |
| Scheduler dispatch failure | SQS DLQ/CloudWatch alarm; không nhầm đây là queue của Lambda task failures |
| Lost state | Pause writers, restore version dưới owner control, reconcile resources, plan trước mutation |

Application-level exception không auto retry vô hạn; Step Functions retries chỉ
cho service/invocation faults. Manual redrive sau điều tra; re-drive qua code update
live alias có thể mismatch release → chạy run mới. Chưa hứa exactly-once hoặc
concurrent-writer correctness.

## 8. Monitoring/logging/access acceptance trước bàn giao

Gắn SNS test receiver được ủy quyền và verify alarm delivery; chưa có subscription
mặc định. Kiểm worker/workflow/CI log groups và logs không chứa payload/credentials.
Kiểm principal tenant A bị deny data/secret/logs tenant B, analytics không đọc raw,
unauthorized user không StartExecution/PassRole. Mock tests không thay AWS tests.

CloudTrail management audit: dùng existing org/account trail hoặc enable optional
bootstrap trail sau cost review và audit_account_is_dedicated=true được owner xác nhận. Không có S3 data-event audit mặc định. Tách AWS API
audit khỏi run/data delivery lineage.

## 9. Rollback và cleanup

Rollback code: deploy previous reviewed source/artifact qua pipeline; verify alias
hash và chạy smoke được phép. Không xóa raw/manifests để rollback code.

Cleanup phải scope đúng tenant/environment, tắt schedule, giữ evidence/state,
review destroy plan. Buckets có prevent_destroy/force_destroy=false; không bypass
hoặc empty bucket tự động. KMS/Secrets có delayed deletion. Endpoint/shared route
impact và retained data/audit/backups cần owner quyết định trước cleanup.
