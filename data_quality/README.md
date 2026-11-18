# Data quality

IMPLEMENTED [snapshot validators](simple/pilots.py): exact fields/types, positive
integer PK, uniqueness, nonblank name, BIT boolean và ISO DATE. Invalid inactive
row vẫn block toàn snapshot. Missing/null/type errors không bị silent cast/repair.

Pipeline giữ raw, ghi quarantine safe row index/error code và không publish khi
DQ fail. Identity/graph/training validators của full platform chưa implement.
[Contract](../contracts/devops/pilot-snapshot.md).
