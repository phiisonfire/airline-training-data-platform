# Airline Training Data Platform — AWS

Repo xây một data platform nhiều airline tenants trên AWS. Milestone hiện tại tập
trung **DevOps với Terraform + AWS CodePipeline/CodeBuild**, dùng business slice nhỏ:
SQL Server test table → immutable raw → validate/map/filter → S3 JSONL + manifest.

**Đã có implementation trong repo**, chưa deploy AWS hoặc kiểm chứng SQL Server
integration. Qualification engine, hai daily BI reports và operational SQL backfeed
được DEFERRED trong milestone này; business requirements đầy đủ vẫn giữ nguyên.

## Bắt đầu học và chạy local

- [Learning path](docs/devops/README.md)
- [Architecture và AWS service inventory](docs/devops/architecture.md)
- [Terraform/state/CDK extension](docs/devops/terraform-and-cdk.md)
- [CI/CD và release security](docs/devops/cicd.md)
- [Setup/deploy/recovery runbook](docs/runbooks/devops-lab.md)
- [20 câu hỏi phỏng vấn kèm code/drills](docs/devops/interview-workbook.md)

Python 3.12, Linux x86_64/WSL và pip:

```bash
python3.12 -m venv .venv
.venv/bin/python -m pip install --require-hashes -r requirements-dev.lock
.venv/bin/python -m pytest -q
.venv/bin/python -m ci.local_demo
```

Demo không cần AWS/SQL: hai source rows → một active pilot → replay không đổi.
Các bước package, Terraform validate/mock tests và dependency audit ở runbook.

## Deployment flow

```text
Repository (CodeConnections)
  → CodeBuild: package / tests / audit
  → CodeBuild: Terraform plan
  → Manual approval
  → CodeBuild: apply exact saved plan
  → CodeBuild: verify published Lambda release
```

Bootstrap controller quản lý state/artifacts, CI roles và pipeline. Platform root
quản lý tenant data plane. Plan role không có state-write; apply role không sửa
controller IAM. Scheduled data workflow disabled cho đến source smoke test.

## Repository map

| Path | Trách nhiệm / implementation |
|---|---|
| `sources/sqlserver/` | Bounded SELECT, TLS, SELECT-only principal, trusted secret binding |
| `pipelines/sql_to_s3/` | Snapshot/replay/publication orchestration và AWS Lambda handler |
| `transformations/simple/` | Pure column mapping và active filter |
| `data_quality/simple/` | Type/date/PK/required-field validation, fail whole snapshot |
| `targets/s3/` | Conditional immutable writes, tenant-bound prefix, SSE-KMS |
| `orchestration/` | Shared ASL workflow definition, infra binds resources |
| `contracts/devops/` | Typed snapshot contract và IaC-neutral deployment schema |
| `config/examples/` | Synthetic deployment example; real non-secret config phải review |
| `infra/terraform/bootstrap/` | CI/CD, state/artifacts, boundaries, optional audit |
| `infra/terraform/platform/` | Tenant/environment composition |
| `infra/terraform/modules/data_plane/` | S3/Lambda/network/secrets/catalog/query/monitoring/workflow |
| `infra/cdk/` | Extension contract; CDK chưa implement, fail explicit |
| `ci/` | Check/package/plan/apply/verify và CodeBuild buildspecs |
| `tests/` | Offline behavior/contract tests, synthetic SQL fixture |
| `governance/`, `observability/` | Policy/operations guides; executable resources trong infra |
| `docs/` | Learning, architecture, ADRs, runbooks, BI handoff và project memory |
| `project_requirements/` | Full business requirements và upstream reference specs |

## Boundaries

Một deployment có bucket/KMS/roles/log groups riêng cho tenant. Chưa mặc định đáp
ứng strict account/network/admin isolation. Không log business payload/PII; không
quản lý password trong Terraform. Source schema là synthetic `devops.pilot_source`,
không suy ra TMDS production DDL từ fixture.

[AWS provider baseline](docs/adr/0001-single-aws-platform.md),
[DevOps milestone ADR](docs/adr/0002-devops-terraform-codepipeline.md),
[business requirements](project_requirements/data_platform_business_requirements.md),
[current evidence](docs/ai-context/CURRENT_STATE.md).

Trước cloud apply cần account/Region/budget, CodeConnections/repository binding,
existing VPC/routes và reviewed plan. Không có remote resources hoặc SQL writes
được thực hiện trong quá trình xây foundation này.
