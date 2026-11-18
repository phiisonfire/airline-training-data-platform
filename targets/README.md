# Targets

Reporting publication/serving adapters và operational SQL Server delivery.

Trạng thái: PROPOSED boundary; documentation foundation, chưa có runtime/config executable.

- Reporting: typed learning/qualification contracts, coherent publication, completeness/freshness, BI handoff.
- SQL: explicit app pilot mapping, agreed enums/schema, lifecycle/error handling và write authority trước integration.
- Durable attempts, stale version rejection, idempotency và ack sau commit; reconcile sau lost ack/outage.
- Không tính qualification trong writer; không dùng warehouse surrogate key làm client identity.
- Không tự migrate hoặc ghi remote target; DDL chỉ là reviewable plan khi contract được chốt.
