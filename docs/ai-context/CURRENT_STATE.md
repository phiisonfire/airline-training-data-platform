# CURRENT_STATE — AWS platform, DevOps milestone

Khởi tạo 2026-11-17; cập nhật 2026-11-18. Đọc README và docs/devops/ để chạy/học.

## Scope và bằng chứng

- ACCEPTED: một platform trên AWS; Terraform trước, extension seam cho AWS CDK.
- ACCEPTED: AWS CodePipeline/CodeBuild; business slice tạm là một SQL test table → mapping/filter → S3.
- IMPLEMENTED trong repo: Python 3.12 snapshot pipeline, Terraform data plane/controller, CI buildspecs, local tests và learning docs.
- Chưa deploy AWS; account/Region/budget/source endpoints/actual IAM/network/SQL integration: UNVERIFIED.
- CDK adapter chưa implement; chọn cdk fail explicit, không fallback.
- Qualification/seniority/two BI serving products/SQL qualification backfeed: DEFERRED trong milestone DevOps, full business scope giữ nguyên.
- Không chuyển test/deployment results của mockgen sang repo này.

## Implementation paths

- sources/sqlserver/extract.py: bounded SELECT-only TLS extraction từ synthetic devops.pilot_source.
- data_quality/simple + transformations/simple: strict types/PK/date/DQ rồi column mapping và active filter.
- pipelines/sql_to_s3: trusted binding, immutable raw/replay, quarantine và manifest-last publication.
- targets/s3/store.py: conditional writes, same payload replay, conflicting payload fail, SSE-KMS.
- orchestration/sql-to-s3.asl.json: Step Functions definition dùng lại; Scheduler disabled mặc định.
- contracts/devops/: snapshot v1 và IaC-neutral deployment JSON schema.
- infra/terraform/bootstrap: state/artifacts/KMS, runtime boundary, CI roles/projects/pipeline và optional audit.
- infra/terraform/platform + modules/data_plane: per-tenant S3/Lambda/KMS/Secrets/network endpoints/Glue/Athena/CloudWatch/SNS/SQS.
- ci/: check/package/plan/apply/verify, owner-only empty state initialization, CodeBuild definitions.
- tests/: offline unit/contract/replay/isolation-binding/CI integrity tests; Terraform mock tests ở IaC roots/module.
- docs/devops/: architecture, Terraform/CDK, CI/CD và 20 interview questions; docs/runbooks/devops-lab.md.

## DevOps boundaries

- Bootstrap controller authority/state khác platform state/apply role; pipeline không sửa controller IAM.
- Remote S3 state native lockfile; plan read/lock, apply state write; owner seed initial backend riêng.
- Build/package/audit → saved plan → approval → exact plan apply → metadata/hash verify.
- Plan bound source/ZIP/backend/boundary/TTL; encrypted artifacts, locked deps/providers.
- Config deployment JSON chỉ non-secret reviewed refs; password nhập ngoài Terraform vào Secrets Manager.
- Existing VPC/routes/source do owner cung cấp; Terraform tạo SG/S3 gateway/Secrets interface endpoints.
- Dedicated bucket/KMS/roles/log groups per tenant deployment là lab resource isolation, chưa strict account/admin isolation.
- Central logging dùng chuẩn/view thống nhất; không copy data-bearing tenant logs vào shared store.
- Optional account-wide CloudTrail chỉ khi dedicated lab account được xác nhận hoặc dùng approved existing audit.
- Default local checks/mock provider không cần AWS credentials, không tạo cloud resources có phí.

## Full business scope — vẫn ACCEPTED

- Một hãng là tenant; SQL/graph/custom mappings riêng; org/location là nội bộ hãng; IDs giữa hãng có thể trùng.
- Phải hỗ trợ yêu cầu không lưu chung data; isolation tier phải chốt, tenant_id/RLS chưa đủ.
- Reporting: hai Power BI learning/qualification serving products 1 lần/ngày; BI dev xây reports.
- Backfeed: current qualification vào SQL Server app, latency thấp nhất khả thi, numeric SLO TBD.
- Hai luồng cùng qualification/identity/policy semantics; checkpoints/retries/recovery riêng; historical report không overwrite app current.
- TMDS employmentdate là source DATE; seniority mapping/version theo hãng, chưa là qualification condition.
- Rehire/leave gaps, exact seniority policy và report cutoff/deadline/timezone còn OPEN.

## Upstream và test provenance

- Upstream mockgen độc lập; baseline reference 0.5.0 / synthetic-v5, actual commit/source location chưa pin.
- DevOps SQL fixture là downstream synthetic lab contract riêng, không phải TMDS production DDL.
- Full source fixtures/registry/QMS chưa ingest. Generator-derived outputs chỉ là validation oracle.
- Validation: lint pass, 43 pytest tests, 3 Terraform mock runs, fmt/validate, runtime dependency audit, local demo và isolated ZIP imports/hash pass.
- Chi tiết trong HISTORY; các checks này không phải SQL/AWS runtime evidence.

## Quyết định / nghiệm thu còn thiếu

- AWS account/Region/budget, isolation tier, VPC/subnets/routes/AZ/DNS, SQL source/TLS trust/read authority.
- CodeConnections AVAILABLE ARN, repository/branch, bootstrap operator và approval permissions.
- Reviewed non-secret config/deployment.json, lab retention, existing endpoints/audit và cleanup ownership.
- AWS plan/apply, post-deploy smoke, tenant negative access, SNS test receiver, alarm delivery và state/data recovery drills.
- Full reporting cutoff/deadline/timezone/late policy và Power BI refresh agreement.
- App SQL identity/schema/enums/write conflicts/lifecycle/error/stale contract và measured numeric SLO.
- Full qualification/latest-attempt/learning/seniority policy contracts và pinned upstream.

## Milestone tiếp theo

1. Review DevOps code/docs và chạy local demo/check suite; hoàn thiện environment/budget/isolation inputs.
2. Owner bootstrap + seed platform state; reviewed platform plan/approval/apply và metadata verify.
3. Source owner chuẩn bị TEST fixture/TLS/secret; controlled workflow smoke rồi enable schedule nếu được duyệt.
4. Verify actual IAM/isolation/logging/alarms/recovery/cost; chỉ sau đó mở rộng business requirements.
