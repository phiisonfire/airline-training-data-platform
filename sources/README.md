# Sources

Discovery và extraction từ TMDS/LMS/ETR SQL Server, Flight HTTP, QMS graph và registry/artifacts.

Trạng thái: PROPOSED boundary; documentation foundation, chưa có runtime/config executable.

- Pin source contract/upstream version; khai báo snapshot, changes, deactivation và tombstone semantics.
- Tenant/source bindings đến từ trusted job config; không tin tenant tự khai trong payload.
- Giữ raw, source timestamps/timezone, revision và lineage; checkpoint sau durable capture.
- Pagination/retry và late corrections phải có tests; registry explicit, không nối IDs theo prefix.
- Không copy generator code hoặc dùng derived oracle làm production input.
