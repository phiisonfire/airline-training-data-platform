# Orchestration

IMPLEMENTED [Step Functions ASL](sql-to-s3.asl.json), Terraform bind worker alias và
partition. EventBridge Scheduler disabled mặc định; SQS DLQ chỉ cho dispatch failure.
Execution name là stable run_id; event không chọn tenant/source/target.

Workflow gọi pipeline entrypoint; không chứa mapping/DQ code. Service invocation
errors có bounded retries; application failures cần investigation/redrive. Full
daily reporting/backfeed/time-trigger qualification workflows chưa implement.
