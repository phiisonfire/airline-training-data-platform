# Tests

Offline tests dưới `unit/` và `infra/`: mapping/filter, type/null/date/PK boundaries,
raw replay/crash-before-manifest, tenant/source binding, SQL TLS/lifecycle (mock),
conditional S3 writes, saved-plan integrity/expiry và empty-state initialization.
`fixtures/pilot_source.sql` chỉ cho SQL Server TEST, owner apply riêng.

Terraform roots/module có mock-provider tests cho IAM quotas, queued pipeline,
boundaries, no public S3/no payload logs/schedule disabled. Không gọi AWS.
SQL/AWS integration, actual negative access, source/network và recovery drills
UNVERIFIED. [Runbook](../docs/runbooks/devops-lab.md).
