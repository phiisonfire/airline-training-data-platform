import hashlib
import json
import sys
import time
from pathlib import Path
from types import SimpleNamespace

import pytest

from ci import iac


@pytest.fixture
def prepared(tmp_path, monkeypatch):
    root = Path.cwd()
    config = json.loads((root / "config/examples/devops-lab.json").read_text())
    config.update(region="us-east-1", vpc_id="vpc-0123456789abcdef0",
                  subnet_ids=["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"],
                  route_table_ids=["rtb-0123456789abcdef0"])
    schema = (root / "contracts/devops/deployment.schema.json").read_text()
    monkeypatch.chdir(tmp_path)
    Path("config").mkdir()
    Path("config/deployment.json").write_text(json.dumps(config))
    Path("contracts/devops").mkdir(parents=True)
    Path("contracts/devops/deployment.schema.json").write_text(schema)
    Path("build").mkdir()
    Path("build/lambda.zip").write_bytes(b"synthetic-zip")
    release = hashlib.sha256(b"synthetic-zip").hexdigest()
    Path("build/release.json").write_text(json.dumps({"sha256": release}))
    iac_root = Path("infra/terraform/platform")
    iac_root.mkdir(parents=True)
    (iac_root / "main.tf").write_text("# synthetic config")
    plan_dir = Path("plan-input")
    plan_dir.mkdir()
    (plan_dir / "tfplan").write_bytes(b"saved-reviewed-plan")
    key = "platform/atdp-dev-airline-a/terraform.tfstate"
    boundary = "arn:aws:iam::123456789012:policy/test-boundary"
    for k, v in {"TF_STATE_BUCKET": "synthetic-state", "TF_STATE_KEY": key,
                 "TF_STATE_KMS_ARN": "synthetic-key", "RUNTIME_BOUNDARY_ARN": boundary,
                 "CODEBUILD_SRC_DIR_PlanOutput": str(plan_dir.resolve())}.items():
        monkeypatch.setenv(k, v)
    monkeypatch.setattr(sys, "argv", ["iac", "apply"])
    calls = []

    def run(command, **kwargs):
        calls.append(command)
        return SimpleNamespace(stdout='{"contract_version":"1"}')

    monkeypatch.setattr(iac.subprocess, "run", run)
    meta = {"source_digest": iac.digest_tree(), "release": release, "state_key": key,
            "boundary": boundary, "created_at": time.time(),
            "plan_sha256": hashlib.sha256(b"saved-reviewed-plan").hexdigest()}
    (plan_dir / "metadata.json").write_text(json.dumps(meta))
    return plan_dir, meta, calls


def test_apply_uses_exact_plan_no_replan(prepared):
    _, _, calls = prepared
    iac.main()
    assert any("apply" in c and c[-1] == "tfplan" for c in calls)
    assert not any("plan" in c for c in calls)
    assert Path("infra/terraform/platform/tfplan").read_bytes() == b"saved-reviewed-plan"


@pytest.mark.parametrize(
    "failure", ["expired", "tampered_plan", "changed_source", "wrong_boundary"])
def test_changed_or_expired_plan_never_applies(prepared, failure):
    directory, meta, calls = prepared
    if failure == "expired":
        meta["created_at"] = time.time() - 86401
    elif failure == "tampered_plan":
        (directory / "tfplan").write_bytes(b"malicious-change")
    elif failure == "changed_source":
        Path("infra/terraform/platform/main.tf").write_text("# changed code")
    else:
        meta["boundary"] = "different"
    (directory / "metadata.json").write_text(json.dumps(meta))
    with pytest.raises(SystemExit, match="mismatch|older"):
        iac.main()
    assert not any("apply" in c for c in calls)
