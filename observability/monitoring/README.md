# Monitoring

Metric definitions, dashboards, alert rules và operational acceptance.

Trạng thái: PROPOSED boundary; documentation foundation, chưa có runtime/config executable.

- Tách job success, DQ state, qualification business status và SQL delivery success.
- Reporting: completeness/freshness, ready time, late/missing publications; deadline/timezone còn OPEN.
- Backfeed: availability/detection/evaluation/queue/commit visibility, p50/p95/p99/max, backlog/oldest pending/stale keys.
- Ghi phần source lag không đo được; job duration không thay end-to-end latency.
- Alerts có safe scope, owner, correlation và runbook; verify bằng test sink, không tự gửi người thật.
