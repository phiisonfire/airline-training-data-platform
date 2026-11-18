# Central logging

Structured logging conventions, redaction, routing, access và central operational view.

Trạng thái: PROPOSED boundary; documentation foundation, chưa có runtime/config executable.

- Logs chứa data ở tenant boundary; central view chỉ nhận/cho truy cập metadata được phép.
- Allowlist opaque run/correlation IDs, stage, release và safe error codes; không log raw, PII, secrets/URLs/custom policy.
- Redact trước emission. Downstream masking không thay thế minimization hoặc isolation.
- CloudWatch là candidate; cross-account visibility/replication cần authorized scopes và isolation agreement.
- CloudTrail là AWS API audit; business/evaluation/delivery audit cần thiết kế riêng.
