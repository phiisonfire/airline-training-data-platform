# Infrastructure

Reviewable AWS resource/IAM/network/storage/state/observability provisioning.

Trạng thái: PROPOSED boundary; documentation foundation, chưa có runtime/config executable.

- Common modules + tenant/environment composition; không fork infra/business logic theo hãng.
- Chưa chọn IaC tool, AWS account/Region, isolation tier, compute/serving/state services hoặc budget.
- Resource definitions tham chiếu workflow/job/dashboard/policy artifacts do module tương ứng sở hữu.
- Plan/preview và schema impact review được trước apply; không tự tạo resources có phí.
- Test negative access/routing/recovery/cleanup và backups; code rollback khác data recovery.
