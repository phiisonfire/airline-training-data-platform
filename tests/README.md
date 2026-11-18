# Tests

Behavioral verification cho từng module và end-to-end platform.

Trạng thái: PROPOSED boundary; documentation foundation, chưa có runtime/config executable.

- Khi có code tổ chức unit, contract, acceptance, integration, isolation/recovery và fixtures theo nhu cầu.
- Fixture inputs gồm raw/source, registry, rule snapshots, manifests/checkpoints, explicit clock và hai tenants IDs trùng.
- Expected assertions độc lập; upstream derived outputs giữ validation-only và pin provenance.
- Cover replay/correction/delete/late/out-of-order, expected learning targets, daily consistency và SQL stale-state/crash recovery.
- Fake sink không chứng minh SQL transaction/access/read visibility. Map AT-01..26 vào test evidence; chưa có runnable tests.
