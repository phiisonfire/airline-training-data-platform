# HISTORY — Data Platform decisions

Append-only. Mỗi thay đổi bền vững ghi một entry ngắn: ngày, rationale, status,
relevant paths và validation thực tế. Không nhập lịch sử code/tests từ mockgen.

## 2026-11-17 — Bootstrap agent instructions và project memory

- ACCEPTED business baseline: nhà cung cấp training cho nhiều airline tenants có sources/mappings riêng; daily serving cho hai Power BI pilot learning/qualification reports do BI dev xây; qualification SQL backfeed cho client app với latency thấp nhất khả thi, numeric SLO TBD; employmentdate cho tenant-specific downstream seniority.
- Rationale: tạo bộ AGENTS.md và docs/ai-context phù hợp repo platform độc lập, giữ ranh giới upstream mockgen và không mang lịch sử implementation/test claims sang repo mới. Architecture và seniority mappings mẫu là PROPOSED; repo đích/runtime chưa khảo sát, chưa ghi nhận IMPLEMENTED platform.
- Paths: AGENTS.md; docs/ai-context/{CURRENT_STATE,BUSINESS_RULES,ARCHITECTURE,HISTORY}.md. Validation chỉ ở bộ tài liệu khi đóng gói: kiểm tra đủ files, internal links, fences và CURRENT_STATE dưới 120 dòng; không chạy application tests/generator, không tạo repo/dependency/cloud resources, không deploy.

## 2026-11-17 — Single AWS platform và repository foundation

- ACCEPTED: người dùng chọn một data platform dùng AWS, bỏ định hướng multi-stack implementations trong cùng repo. Business semantics, tenant isolation và hai output paths giữ nguyên; account/Region/budget/services/runtime/IaC/CI provider còn OPEN.
- PROPOSED: responsibility-based layout cho sources/pipelines/transformations/targets/orchestration/data_quality/contracts/config/governance/observability/infra/ci/tests; central operational logging view không mặc định gom data-bearing tenant logs. AWS service candidates không phải service list đã duyệt.
- Rationale: repo tập trung xây một platform có operational boundaries rõ thay vì nhiều bài triển khai theo stack. Chỉ tạo documentation foundation/module guides; chưa có runtime, executable IaC, application tests hoặc deployment.
- Paths: README.md; docs/architecture/aws-platform.md; docs/adr/0001-single-aws-platform.md; module README files; project_requirements/data_platform_business_requirements.md mục 1.2; docs/ai-context/{CURRENT_STATE,BUSINESS_RULES,ARCHITECTURE,HISTORY}.md.
- Validation: đã kiểm tra local links, balanced code fences và trailing whitespace cho 19 Markdown guides mới; CURRENT_STATE 75 dòng (<120); git diff --check không báo lỗi (các files mới/untracked được kiểm bằng script riêng). Đối chiếu capabilities trong AWS docs cho Step Functions, Lake Formation và CloudWatch. Application/integration/IaC checks NOT RUN vì chưa có implementation; không đọc secrets, ghi SQL remote, tạo cloud resources hoặc deploy.

## 2026-11-18 — DevOps-first implementation: Terraform, CodePipeline và study docs

- ACCEPTED: người dùng ưu tiên CI/CD và IaC Terraform có đường mở rộng AWS CDK, chọn AWS CodePipeline; tạm thu hẹp business slice thành một SQL Server test table → mapping/filter → S3, đồng thời cần docs học/phỏng vấn. Full reporting/qualification/backfeed/seniority scope giữ nguyên nhưng DEFERRED trong milestone này.
- IMPLEMENTED trong repo: Python 3.12 bounded snapshot, strict DQ, immutable raw/replay/curated/manifest và safe errors; Terraform bootstrap/controller + tenant data plane cho S3/KMS/Secrets/Lambda/private endpoints/Step Functions/Scheduler/SQS/Glue/Athena/CloudWatch/SNS, optional dedicated-account CloudTrail; CodeBuild build/plan/apply/verify và CodePipeline source/approval. CDK có input/output/artifact seam, chưa có CDK app và fail explicit khi chọn.
- Rationale: làm business slice đủ nhỏ để tập trung state/locking, IAM/tenant boundaries, immutable release/saved-plan approval, packaging, observability và recovery. Bootstrap authority/state tách platform; owner-only empty-state initialization; no controller IAM escalation trong apply scope. Resource-level lab isolation chưa là strict tenant tier.
- Paths: pyproject.toml, requirements*.lock; sources/sqlserver/, data_quality/simple/, transformations/simple/, pipelines/sql_to_s3/, targets/s3/; orchestration/sql-to-s3.asl.json; contracts/devops/, config/examples/; infra/terraform/{bootstrap,platform,modules/data_plane,testing}, infra/cdk/; ci/; tests/{unit,infra,fixtures}; docs/devops/, docs/runbooks/devops-lab.md, docs/adr/0002-devops-terraform-codepipeline.md; README/module guides, requirements mục 1.3 và project memory.
- Validation thực tế: ruff pass; pytest 43 passed; Terraform 1.14.6 fmt/validate pass cho bootstrap/platform/data_plane và 3 mock-provider test runs pass (không gọi AWS); hashed Lambda ZIP build và isolated imports/TLS check không dùng site-packages, archive source/hash khớp code hiện tại; local demo 2 source rows → 1 output, replay unchanged; python-tds TLS context initialized; runtime pip-audit không tìm thấy known vulnerabilities tại thời điểm chạy. Full local check entrypoint ci/check.py pass. Provider validation/mock tests cần local plugin socket ngoài sandbox, không phải remote apply.
- AWS account/Region/budget/CodeConnections/repo/network/source credentials chưa cung cấp. Không deploy, tạo paid resources, ghi remote SQL hoặc kiểm chứng actual IAM/source connectivity/alarms/recovery. Bootstrap/plan/apply/verify definitions có code nhưng cloud executions UNVERIFIED; không claim full business acceptance hoặc production readiness.

## 2026-11-19 — Bootstrap source chuyển sang CodeCommit

- ACCEPTED/IMPLEMENTED theo yêu cầu user: thay CodeConnections bằng existing CodeCommit repository cùng account/Region; repository_name/branch, CODE_ZIP, polling explicit. Không tạo remote repository.
- Pipeline source IAM giới hạn năm archive/branch/commit actions vào đúng repository ARN; bỏ UseConnection. Operator push source trước apply; approval/platform state boundaries giữ nguyên.
- Paths: infra/terraform/bootstrap/{variables.tf,pipeline.tf,terraform.tfvars.example,tests/security.tftest.hcl}; docs/devops/{cicd.md,architecture.md}, docs/runbooks/devops-lab.md và project memory.
- Validation: Terraform fmt check, validate và 1 mock-provider test run pass (source config/repository IAM assertions). Provider validate/tests chạy ngoài sandbox để dùng local socket; không gọi AWS, không đọc credentials, không deploy. AWS runtime/Free Plan account-specific availability UNVERIFIED.

## 2026-11-19 — Destructive cleanup cho lab

- ACCEPTED/IMPLEMENTED: theo yêu cầu user, bỏ prevent_destroy ở buckets data/control/audit, force_destroy=true; KMS deletion window=7, Secrets Manager recovery window=0. Không áp dụng làm production defaults.
- Runbook docs/runbooks/devops-lab-cleanup.md: dừng writers, áp dụng flags vào existing state, destroy platform bằng owner, migrate bootstrap backend về local rồi destroy bootstrap; inventory ngoài Terraform và kiểm tra billing riêng. Không hứa zero charges hoặc xóa KMS tức thì.
- Paths: infra/terraform/bootstrap/{main.tf,audit.tf,tests/security.tftest.hcl}, infra/terraform/modules/data_plane/{main.tf,tests/security.tftest.hcl}; docs/devops/{README.md,terraform-and-cdk.md}, docs/runbooks/{devops-lab.md,devops-lab-cleanup.md}, project memory.
- Validation: Terraform fmt check, validate bootstrap/platform/data_plane, 2 mock-provider test runs pass với cleanup flag assertions; git diff --check pass. Provider checks ngoài sandbox cho local socket, không gọi AWS. Cleanup/deletion/billing thực tế UNVERIFIED; không đọc credentials hoặc xóa resources.

## 2026-11-19 — Bootstrap S3 backend template và migration guide

- IMPLEMENTED: template backend.tf.example và local ignored backend.tf khai báo S3; runbook thêm backup local state, first-apply chưa xong, migration có xác nhận, bootstrap key riêng và verification/re-plan. Kiến trúc local-first rồi remote S3 không đổi.
- Paths: infra/terraform/bootstrap/backend.tf.example, docs/runbooks/devops-lab.md, CURRENT_STATE.
- Validation: terraform fmt -check backend.tf và git diff --check pass. Không init/migrate/apply, không đọc state/credentials, AWS migration UNVERIFIED.

## 2026-11-19 — Two-VPC source/provider lab topology

- ACCEPTED/IMPLEMENTED theo yêu cầu user: Source VPC mô phỏng network hãng, Platform VPC mô phỏng provider. Root network do operator quản lý state riêng; cùng account/Region, derived disjoint CIDRs, 2 AZ/4 private subnets, peering + forward/return routes và SQL-only ingress từ platform subnet CIDRs. Không tạo SQL/NAT/IGW hoặc tăng quyền CI sang source network.
- Network contract v1 trả source IDs/SG cho source owner và platform_inputs tương thích deployment schema v1. CI checks thêm network init/validate/mock tests; ci/iac.py vẫn chỉ deploy platform. Existing deployment cần reviewed migration plan, không tự apply.
- Paths: infra/terraform/network/{main.tf,terraform.tfvars.example,.terraform.lock.hcl,tests/boundaries.tftest.hcl}, infra/terraform/platform/main.tf, ci/check.py, config/{README.md,examples/devops-lab.json}, docs/runbooks/{two-vpc-lab.md,devops-lab.md,devops-lab-cleanup.md}, docs/devops/architecture.md, infra/README.md và memory.
- Validation: network init -backend=false -lockfile=readonly, validate và 3 mock test runs pass (disjoint boundaries/private subnets/forward-return routing/SQL-only ingress/output routing, invalid CIDR/AZ rejection); tests/infra 12 passed, ruff ci/check.py pass, changed Terraform fmt check và git diff --check pass. Checks dùng local provider socket ngoài sandbox; không init remote backend, không đọc credentials/state hoặc tạo resources AWS. SQL/DNS/TLS, negative access và cloud deployment UNVERIFIED.
- Runtime provenance correction: user đã báo bootstrap AWS apply 48 resources ở Singapore trước thay đổi này; đó không phải bằng chứng network/platform mới đã deploy.

## 2026-11-19 — Single-VPC thay two-VPC lab

- ACCEPTED/IMPLEMENTED theo user: SUPERSEDED topology hai VPC bằng một VPC, ba application/database/platform private subnet groups, mỗi group hai subnets ở hai AZ; 6 route tables/associations, dùng local route, bỏ peering và peer routes. SQL ingress chỉ TCP port đã cấu hình từ platform subnet CIDRs. Không tạo application/SQL compute hoặc Internet egress.
- Network contract v2 đổi source IDs thành shared vpc_id + application_subnet_ids/database_subnet_ids/database_sql_security_group_id; platform_inputs vẫn tương thích deployment schema v1. Same-owner lab, không còn mô phỏng independent airline/provider network ownership. Bootstrap không đổi; existing two-VPC deployment phải review migration/cleanup, không tự migrate state.
- Paths: infra/terraform/network/{main.tf,tests/boundaries.tftest.hcl}, tests/infra/test_ci_contract.py, config/{README.md,examples/devops-lab.json}, infra/terraform/platform/main.tf, docs/runbooks/{single-vpc-lab.md,two-vpc-lab.md,devops-lab.md,devops-lab-cleanup.md}, docs/devops/architecture.md, infra/README.md và memory.
- Validation: network validate và 4 mock runs pass (single VPC/subnet roles/AZ/SQL ingress/contract/custom port, invalid CIDR/AZ rejection). Terraform formatting/git diff checks pass. Python infra topology guard kiểm tra không peering/Internet egress; initial parser assertion sửa để xử lý HCL quoted labels. Không apply/migrate AWS, không đọc credentials/state; actual SQL/TLS/negative access UNVERIFIED.

## 2026-11-20 — Bỏ Lambda reservation trong lab

- ACCEPTED/IMPLEMENTED theo user: worker dùng reserved_concurrent_executions=-1, shared account pool, thay reservation=1 bị AWS từ chối với account concurrency quota 10. Không có function-level cap; giữ schedule disabled và manual runs từng workflow. Không suy ra concurrent-writer guarantee.
- Paths: infra/terraform/modules/data_plane/main.tf, docs/devops/architecture.md, docs/ai-context/{ARCHITECTURE,CURRENT_STATE}.md.
- Validation: data_plane Terraform mock test 1 passed; Terraform fmt và git diff --check pass. Không apply AWS; deployment mới UNVERIFIED.
