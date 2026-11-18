# ADR 0002 — DevOps-first slice: Terraform + CodePipeline, CDK extension

Ngày: 2026-11-18.

## ACCEPTED scope

Người dùng yêu cầu tập trung CI/CD và Terraform, có đường mở rộng AWS CDK; chọn
AWS CodePipeline. Business logic tạm đơn giản: extract một SQL table, mapping,
filter và ghi S3. Cần bao phủ component categories của platform và docs học/phỏng vấn.

## IMPLEMENTED trong repo, deployment UNVERIFIED

Python 3.12 bounded full snapshot Lambda; Step Functions/Scheduler; tenant S3/KMS,
Secrets metadata; SG/private AWS endpoints dùng existing VPC; Glue/Athena; logs,
alarms/dashboard/SNS; CI controller S3 state/artifacts, roles/boundary, CodeBuild
build/plan/apply/verify + CodePipeline source/manual approval. Optional CloudTrail
chỉ khi dedicated lab account được xác nhận, tránh duplicate hoặc cross-tenant audit.

Service/compute choices là chi tiết kỹ thuật của slice, không numeric business
SLA. Lambda timeout/max_rows và alarm evaluation windows không phải backfeed SLA.
Source là test contract riêng, không tự chọn physical TMDS production columns.

## Consequences

- Bootstrap controller và platform states/authorities tách riêng; initial platform
  backend do owner seed, plan không được ghi state chính.
- Saved plan gắn source/release/state/boundary và TTL; exact plan apply sau approval.
- Common deployment/output contracts và artifact để thêm CDK; CDK adapter chưa có.
  Không có hai IaC owners cho một resource.
- Qualification/learning/seniority/reporting/backfeed đầy đủ DEFERRED trong slice
  này, giữ business requirements gốc và acceptance backlog.
- No cloud apply/paid resources/SQL remote writes trong task implementation local.

## Validation evidence

Xem CURRENT_STATE/HISTORY cho commands/results thực tế. Mock/provider validation
không chứng minh IAM enforcement, AWS integration, source connectivity hay recovery.
