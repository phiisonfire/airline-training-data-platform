# Pipelines

IMPLEMENTED [SQL to S3](sql_to_s3/job.py): full snapshot, raw checkpoint, DQ gate,
column mapping/filter, immutable output và manifest-last publication. AWS handler
ở `sql_to_s3/handler.py`. Không có business qualification engine hoặc SQL backfeed.

Retry cùng binding/run tái dùng raw; historical/current operational semantics của
full platform vẫn giữ trong business requirements. [Runbook](../docs/runbooks/devops-lab.md).
