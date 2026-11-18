# DevOps lab contract v1

Owner/steward: lab platform engineer (synthetic role). Classification: synthetic
personal/training identifiers; still tenant-restricted. Version: 1. Product is a
full snapshot, not CDC, qualification, learning status or app SQL backfeed.

Source: explicitly provisioned TEST table `devops.pilot_source`; this is not a
claim about upstream TMDS physical columns. Source principal has SELECT only.
Grain: one row/source_id, positive SQL INT PK (1..2147483647); display_name NVARCHAR(100) nonblank;
is_active BIT required; employmentdate DATE required (no timestamp). No nullable
fields. Expected fields exact; invalid/duplicate rows block the whole publication,
including invalid inactive rows. Raw is a JSON serialization of selected DBAPI
column values (SQL DATE becomes ISO date), not byte-for-byte SQL storage capture.

Mapping: source_id → pilot_id; display_name → pilot_name; employmentdate →
employment_date; filter is_active=true. No trimming/casting/repair. Trusted job
binding adds tenant_id and run_id. Target grain: tenant × run_id × pilot_id.
JSONL fields: tenant_id:string, pilot_id:int, pilot_name:string,
employment_date:ISO date string, run_id:string; all non-null. No relationships yet.
Future employmentdate is preserved: no seniority calculation in this slice.

Dedicated S3 bucket per tenant deployment; key prefix tenant=<id>/. Raw snapshot,
quarantine safe issue indexes/codes, immutable curated JSONL and success manifest
are separate prefixes. Athena run_id is an injected partition: every query must
select an explicit successful run from its manifest. Do not aggregate all snapshots.

A stable run_id is one Step Functions execution ID/name; retries reuse committed
raw, no source reread. Binding includes tenant/schema/table/release/max_rows; reuse
of a run with changed binding/payload fails. Concurrent source extraction before
raw commit may conflict; no distributed snapshot/concurrent-writer guarantee.
One SELECT has source's configured isolation, not a multi-table coherent snapshot.

Bounded lab: max_rows defaults 10000; >limit fails, never silently truncates.
Empty snapshot succeeds with output_count=0. No latest pointer or incremental
watermark. Manifest is committed last; consumers check success before query.
S3/Athena does not enforce manifest gating automatically. Retention is configurable
and applies coherently to raw, curated and manifests; account contract still OPEN.
