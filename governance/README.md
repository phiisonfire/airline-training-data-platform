# Data governance

Ownership/stewardship, catalog, classification, lineage, access, retention và audit.

Trạng thái: PROPOSED boundary; documentation foundation, chưa có runtime/config executable.

- Trace serving result về canonical identity, raw evidence, rule/policy version và publication/evaluation.
- Least privilege theo ingestion/transformation/consumer/deployment; manager scopes không thay tenant boundary.
- Isolation bao phủ raw/curated/state/graph/quarantine/temp/logs/BI/cache/exports/backups.
- Retention phải giữ đủ evidence cho recovery/history; không tự nhận các số lab proposal là accepted policy.
- IAM/KMS và catalog/access resources đặt trong infra; governance sở hữu policy intent và access acceptance.
