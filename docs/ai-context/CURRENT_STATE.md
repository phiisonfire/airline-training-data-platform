# CURRENT_STATE — Data Platform bootstrap

Ngày khởi tạo: 2026-11-17. Đây là baseline tài liệu cho repo platform mới.
Repo đã khảo sát: requirements/docs và `.gitignore`; chưa có runtime/manifests/tests.

## Trạng thái bằng chứng

- CURRENT ARTIFACTS: requirements, project memory, README/module guides, AWS blueprint và ADR 0001.
- IMPLEMENTED PLATFORM: chưa có; hiện mới documentation/repository foundation.
- Runtime/deployments/cloud resources/source endpoints/target SQL: UNVERIFIED.
- Application/unit/integration/performance tests trong repo đích: NOT RUN.
- Không chuyển kết quả tests hoặc lịch sử triển khai mockgen sang platform memory.

## Business scope — ACCEPTED

- Một data platform dùng AWS; bỏ hướng nhiều stack implementations trong cùng repo.

- Công ty cung cấp giải pháp training cho nhiều hãng hàng không.
- Một hãng là một tenant; SQL Server sources, graph database và custom mappings riêng.
- Organization/location thuộc nội bộ hãng, không là tenant; IDs giữa hãng có thể trùng.
- Hỗ trợ khách yêu cầu data không lưu chung với hãng khác; isolation tier cần chốt.
- Reporting: serving layer cho Power BI pilot learning status và pilot qualification status reports, công bố 1 lần/ngày. BI dev xây reports.
- Backfeed: pilot qualification status ghi tới targeted SQL Server cho application client; latency càng nhỏ càng tốt, numeric SLO TBD.
- Hai luồng dùng chung qualification semantics, không bắt backfeed chờ daily reporting.
- TMDS employmentdate là input; downstream tính seniority theo số năm employed và mapping có version riêng theo hãng.
- Seniority chưa là điều kiện qualification; rehire/leave-gap semantics chưa chốt.

## Upstream source reference

- Repo upstream: pilot_training_platform_mock_data_generator; độc lập với repo này.
- Baseline tham chiếu khi soạn: mockgen 0.5.0, source contract synthetic-v5.
- Upstream commit/release/source location thực tế: cần xác minh và pin khi bootstrap.
- Domains: TMDS, LMS, ETR, Flight API, QMS; registry nối source IDs trong hãng.
- employmentdate: source ISO YYYY-MM-DD / SQL Server DATE; raw và derived tách riêng.
- Mockgen SQL publish là source fixture publishing, không phải app qualification backfeed.
- Chi tiết reference và giới hạn: [BUSINESS_RULES.md](BUSINESS_RULES.md).

## Architecture direction — PROPOSED

- Tenant data planes tách biệt, common code/IaC templates, control metadata tối thiểu.
- Bronze raw → Silver canonical/history/DQ; qualification evaluation history dùng chung.
- Nhánh daily: Gold star/SCD2/bridges/data marts và hai BI serving contracts.
- Nhánh operational: incremental/time-triggered evaluation → durable delivery → target SQL current qualification state.
- Checkpoints/retries/publications/recovery độc lập; reconcile tại cùng source/rules/as-of.
- Seniority snapshot theo tenant/user/as-of/policy version; không static trong employee dim.
- AWS đã chọn; services/engine/orchestrator/account/Region/IaC/physical schemas còn OPEN.
- Repo responsibilities và service candidates: [AWS blueprint](../architecture/aws-platform.md), PROPOSED.
- Central logging có chuẩn/view thống nhất; data-bearing logs giữ tenant boundary.
- Chi tiết responsibilities và failure boundaries: [ARCHITECTURE.md](ARCHITECTURE.md).

## Quyết định còn mở

- AWS account/Region/budget, service list, language/dependencies, IaC/CI provider và test environment.
- Ingestion mode: local artifacts hay SQL/graph/HTTP integration; source capabilities và registry delivery.
- Reporting cutoff/deadline/business timezone/calendar và late-source policy.
- Backfeed numeric latency SLO sau đo đạc; source availability/CDC/polling constraints.
- Target SQL schema/keys/client identity/enums/write authority và lifecycle/error/stale handling.
- Latest ETR/exam attempt policy; upstream reference dùng snapshot order.
- Seniority bands, completed-years semantics, Feb-29 handling và policy effective dates.
- Isolation tier, permissions/scopes, retention, scale, RPO/RTO và operational thresholds.

## Milestone tiếp theo — PROPOSED

1. Chốt runtime và contracts cho artifact vertical slice; AWS resource plan sau environment/budget.
2. Xác minh business baseline; ghi ADR/decisions chỉ cho lựa chọn ảnh hưởng thiết kế.
3. Pin source fixtures/contract, chốt grains/identity/expected results cho hai hãng.
4. Làm vertical slice nhỏ: daily learning/qualification serving + qualification SQL backfeed.
5. Kiểm chứng identity/isolation, DQ, replay, stale-state guard và recovery, rồi mở rộng vận hành.

## Memory maintenance

- Đọc CURRENT_STATE một lần/phiên; giữ dưới khoảng 120 dòng.
- Chỉ nâng PROPOSED → ACCEPTED khi có quyết định; IMPLEMENTED cần source evidence.
- HISTORY append-only; không chép transcript, secrets hoặc test claims chưa chạy.
- Requirements và data model proposal hiện có trong project_requirements/.
