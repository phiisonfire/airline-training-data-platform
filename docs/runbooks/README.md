# Runbooks

Operational procedures để verify khi có implementation.

Trạng thái: PROPOSED boundary; documentation foundation, chưa có runtime/config executable.

- Bao phủ daily publication failure, source lag/DQ remediation, SQL backlog/outage, replay/backfill và lost ack recovery.
- Mỗi runbook cần trigger, owner, safe diagnosis, tenant scope, recovery/rollback và verification.
- Cleanup phải dry-run/scoped, giữ lineage và tenant khác an toàn; không điền commands chưa được verify.
- Runtime, access và recovery drills hiện UNVERIFIED.
