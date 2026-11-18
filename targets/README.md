# Targets

IMPLEMENTED [S3 immutable store](s3/store.py): tenant-bound prefix, conditional
write, same key/body replay và conflict nếu khác payload. SSE-KMS, TLS và policies
được khai báo Terraform. Glue/Athena query explicit run_id; consumer kiểm manifest.

SQL Server qualification sink và hai BI report-facing products chưa implement.
Không coi S3 pilot snapshot là full business deliverable. [Runbook](../docs/runbooks/devops-lab.md).
