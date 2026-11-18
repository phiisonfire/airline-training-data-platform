# CI/CD

IMPLEMENTED CodePipeline/CodeBuild definitions; cloud executions UNVERIFIED.

- `check.py`: lint, pytest, Terraform fmt/validate và mock-provider tests.
- `package.py`: pinned/hashed Linux Python 3.12 Lambda ZIP và release hash.
- `iac.py`: IaC adapter validate/plan/apply, exact saved-plan/source/state checks.
- `verify.py`: published Lambda hash và workflow metadata, không chạy SQL.
- `initialize_state.py`: owner-only one-shot empty backend seed, không reset state.
- `codebuild/`: Build/Plan/Apply/Verify commands; approval ở CodePipeline.

[CI/CD guide](../docs/devops/cicd.md), [learning path](../docs/devops/README.md).
CDK adapter chưa implement; select CDK fail explicit. Không có access keys trong repo.
