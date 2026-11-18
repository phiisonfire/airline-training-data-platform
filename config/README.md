# Configuration

Versioned environment/tenant bindings và synthetic policy examples.

Trạng thái: PROPOSED boundary; documentation foundation, chưa có runtime/config executable.

- Trusted tenant binding khai báo source/target resource refs, isolation tier, release và policy references.
- Chỉ commit schemas, synthetic examples và secret references; không credentials, connection URLs hoặc real PII.
- Custom policies thực tế giữ trong tenant boundary; không đưa nội dung policy của hãng vào shared control metadata.
- Không fallback tenant/pilot/policy; detect missing/overlapping configuration trước writes.
- Account/Region/budget và target write authority chưa được chọn.
