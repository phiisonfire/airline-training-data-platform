# DevOps learning path — AWS data platform

Ngày: 2026-11-18. Mục tiêu hiện tại: học IaC/CI/CD/operations với một business
slice nhỏ; chưa nghiệm thu toàn bộ platform airline.

## Đọc và thực hành theo thứ tự

1. [Architecture và service ownership](architecture.md): vẽ được data plane,
   control plane, trust boundaries và failure paths.
2. [Terraform và CDK extension](terraform-and-cdk.md): giải thích state, lock,
   module/root boundaries, immutable plan, drift, import và migration ownership.
3. [CodePipeline và release security](cicd.md): trace một commit qua artifacts,
   tests, plan, approval, apply và verify; phân biệt CI/CD workflow với data workflow.
4. [Deploy/recovery runbook](../runbooks/devops-lab.md): các bước local → bootstrap
   → first deployment → source secret → controlled smoke → rollback/recovery.
5. [Interview workbook](interview-workbook.md): tự trả lời, dẫn code và thực hiện
   failure drills trước khi nói “tôi đã triển khai”.

## Bằng chứng cần thu thập khi học

| Bài thực hành | Bằng chứng |
|---|---|
| Local checks | Lint/tests, Terraform validation/mock-test output, dependency audit |
| Artifact | ZIP hash, requirements hashes và provider lockfiles |
| First deploy | Reviewed plan, approval, apply output, published Lambda hash |
| Source integration | SQL principal SELECT-only, TLS, route/SG, matching raw/curated/manifest |
| Failure drill | DQ không publish; redrive dùng raw; wrong tenant bị chặn; expiry plan không apply |
| Operations | Alarm tới authorized test sink, log redaction/access, state recovery drill |

Không chuyển mock/local results thành claim đã chạy AWS. Platform completion vẫn
cần đầy đủ reporting/backfeed/isolation acceptance trong business requirements.

## Scope hiện tại

IMPLEMENTED trong repo: Python 3.12 bounded snapshot pipeline, Terraform resources,
CodePipeline/CodeBuild definitions và tests. AWS deployment, SQL integration,
actual IAM enforcement và recovery drills: UNVERIFIED nếu chưa có run evidence.
Qualification/seniority, learning reports và operational SQL backfeed: DEFERRED
cho milestone DevOps này; business requirements gốc vẫn giữ nguyên.
