# Orchestration

Triggers, schedules, workflow dependencies và execution policies.

Trạng thái: PROPOSED boundary; documentation foundation, chưa có runtime/config executable.

- Workflows riêng cho ingestion, daily reporting, operational reevaluation/delivery và reconciliation.
- Include time triggers cho expiry/rolling windows; không chỉ chờ CDC.
- Workflow gọi pipeline entrypoints, áp dụng gate outputs; không duplicate transformations/DQ logic.
- Retries cần idempotency và durable checkpoints; không che business/DQ failure thành successful publication.
- Step Functions/EventBridge Scheduler là candidates, chưa có state machines/deployed schedules.
