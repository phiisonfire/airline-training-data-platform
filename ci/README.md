# CI/CD

Check/build/release/promotion contract; CI provider chưa chọn.

Trạng thái: PROPOSED boundary; documentation foundation, chưa có runtime/config executable.

- Default checks local/offline, synthetic fixtures, không cần production credentials hoặc tự tạo cloud resources.
- Focused logic/contracts/acceptance trước; integration/IaC/security checks theo phạm vi implementation.
- Pin dependencies khi có manifests, version code/config/contracts/policies/IaC và release provenance.
- Provider workflow gọi cùng scripts đã kiểm chứng; chưa có build/test/deploy commands ở scaffold này.
- Review IaC/schema impact; deployment và data backfill có quy trình riêng, scoped authorization.
