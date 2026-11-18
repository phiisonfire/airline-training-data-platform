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
