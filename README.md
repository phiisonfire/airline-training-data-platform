# Airline Training Data Platform — AWS

Một repository cho một data platform trên AWS, phục vụ nhiều airline tenants.
Không tổ chức thành nhiều implementations theo cloud/framework. Common code và
IaC templates được dùng lại qua tenant-bound configuration.

**Trạng thái:** repository foundation và architecture proposal; chưa có pipeline
runtime, dependency manifest, automated tests, IaC executable hoặc deployment.
AWS là lựa chọn ACCEPTED; service mapping và cấu trúc chi tiết là PROPOSED.

## Điểm bắt đầu

- [Business requirements](project_requirements/data_platform_business_requirements.md)
- [Data model proposal](project_requirements/data_platform_data_model.md)
- [AWS architecture và repo boundaries](docs/architecture/aws-platform.md)
- [ADR: một platform trên AWS](docs/adr/0001-single-aws-platform.md)
- [Current state](docs/ai-context/CURRENT_STATE.md)

## Repository map

| Path | Trách nhiệm |
|---|---|
| `sources/` | Source discovery, extraction, raw capture, ingestion checkpoints |
| `pipelines/` | Use cases end-to-end: ingestion, daily reporting, operational backfeed, replay |
| `transformations/` | Canonicalization, identity, assignments, qualification, seniority, Gold models |
| `targets/` | Reporting publication/serving và SQL Server delivery adapters |
| `orchestration/` | Triggers, schedules, workflow definitions, execution/recovery wiring |
| `data_quality/` | Validators, severity/gates, quarantine và reconciliation |
| `contracts/` | Source, canonical, reporting, backfeed và configuration contracts |
| `config/` | Environment/tenant config schemas, synthetic examples, secret references |
| `governance/` | Ownership, classification, lineage, access, retention, audit policies |
| `observability/monitoring/` | Metrics, dashboards, alert rules và measurement definitions |
| `observability/logging/` | Structured logging, redaction, tenant boundaries, central operational view |
| `infra/` | AWS resource definitions, permissions, environment composition và plans |
| `ci/` | Provider-independent check/build/release scripts và CI contract |
| `tests/` | Unit, contracts, acceptance, integration, isolation/recovery và fixtures |
| `docs/` | Architecture, ADRs, BI handoff, runbooks, project memory |
| `project_requirements/` | Input requirements/specifications; generator spec chỉ là upstream reference |

Các thư mục hiện có README mô tả ownership; chưa phải modules chạy được. Chốt
language/package layout khi triển khai slice đầu tiên; không dùng folder names
để ngầm chọn Python, Spark, dbt, Terraform hay CI provider.

## Hai output paths

Source → raw → canonical/history/DQ → versioned qualification evaluation.

- Reporting: canonical/evaluation tại cutoff → daily Gold → validate → coherent
  publication cho learning status và qualification status; BI dev xây Power BI.
- Backfeed: authoritative current evaluation → durable delivery → target SQL
  transaction → acknowledgement/reconciliation; không chờ daily Gold.

Mọi dữ liệu, graph rules, quarantine và delivery/checkpoint state thuộc tenant
boundary. Central logging không mặc định gom business data của các hãng.

## Validation và bước tiếp theo

Chưa có application test/build/deploy commands. Không suy ra stack từ `.gitignore`.
Xây slice local/artifact có explicit clock và hai synthetic tenants trước; pin
upstream, chốt grains/contracts, verify replay và hai output paths. Sau đó triển
khai AWS bằng environment/budget/isolation tier được xác nhận và IaC plan review
được. Fake SQL sink chỉ kiểm chứng logic delivery; cần SQL Server test để nghiệm
thu transaction/read visibility/recovery thực tế.
