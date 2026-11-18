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
