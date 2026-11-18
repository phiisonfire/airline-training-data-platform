# Pipelines

Application use cases end-to-end; phối hợp sources, transformations, DQ và targets.

Trạng thái: PROPOSED boundary; documentation foundation, chưa có runtime/config executable.

- Các use cases: ingest source state; daily learning/qualification publication; current qualification backfeed; scoped replay/reconciliation.
- Run context explicit: tenant binding, correlation, source checkpoints, versions và evaluation as-of.
- Reporting/backfeed giữ checkpoint, retry và recovery riêng; backfeed không đợi daily Gold.
- Historical backfill chỉ tạo analytical publication; muốn repair app phải reevaluate authoritative current state.
- Không đặt SDK-specific workflow definitions hoặc business calculations trực tiếp ở đây.
