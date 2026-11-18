# Contracts

IMPLEMENTED [DevOps snapshot v1](devops/pilot-snapshot.md) và
[IaC-neutral deployment schema](devops/deployment.schema.json). Source synthetic test
contract không thay TMDS schema; downstream data có grain/types/nullability/owner
và snapshot/retry semantics rõ. Terraform output contract v1 ở module outputs.tf.

Full source/canonical/reporting/backfeed/configuration contracts vẫn cần chốt theo
business scope. Đồng bộ code/validators/DDL/consumers khi mở rộng, pin upstream.
