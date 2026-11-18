# Sources

IMPLEMENTED lab connector: [sqlserver/extract.py](sqlserver/extract.py). SELECT bounded
một synthetic test table; encrypted session + hostname validation, SELECT-only
credential lấy từ tenant-bound Secrets Manager. Không write/migrate source.

Snapshot contract: [devops v1](../contracts/devops/pilot-snapshot.md). Upstream TMDS/
LMS/ETR/Flight/QMS discovery/incremental connectors chưa implement. Source tenant
không được chọn routing; registry/source mappings đầy đủ vẫn cần pin khi mở domain.
