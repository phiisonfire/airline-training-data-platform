# ADR 0001 — Một data platform trên AWS

Ngày: 2026-11-17.

## Quyết định — ACCEPTED

Theo yêu cầu người dùng, repo phục vụ một data platform dùng AWS services.
Không tiếp tục mục tiêu nhiều implementations theo stack trong cùng repo.
Tenant-specific configuration và isolation vẫn là yêu cầu; không fork business
logic cho từng hãng khi cấu hình giải quyết được.

## Thiết kế chi tiết — PROPOSED

Tổ chức theo responsibilities: sources, pipelines, transformations, targets,
orchestration, data quality, contracts, governance, observability, infra và CI/CD.
Chi tiết nằm trong [AWS blueprint](../architecture/aws-platform.md).

Các đề xuất `stacks/aws`, `stacks/azure`, `stacks/databricks`, `stacks/snowflake`
và multi-stack lab profiles trong trao đổi trước được SUPERSEDED về định hướng.
Yêu cầu business, source semantics và hai output paths không thay đổi.

## Hệ quả và quyết định còn mở

- Không cần lớp abstraction để hỗ trợ nhiều cloud; vẫn tách domain logic khỏi I/O.
- AWS provider đã chọn; account, Region, budget, isolation tier và service list chưa chọn.
- Chưa chọn language, engine, table format, IaC tool hoặc CI/CD provider.
- Không mặc định migrate SQL sources/target hoặc graph sang một AWS database.
- Quyết định này không cấp quyền deploy, tạo resources có phí hay ghi remote SQL.

## Bằng chứng

Repo hiện có requirements và project memory, chưa có runtime/manifests/tests.
Lượt này tạo documentation foundation; chưa triển khai AWS hoặc pipelines.
