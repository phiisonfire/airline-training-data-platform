"""Versioned IaC adapter interface: validate/plan/apply. CDK must fail closed today."""
from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import os
import re
import shutil
import subprocess
import time
from pathlib import Path

from jsonschema import validate

ROOT = Path("infra/terraform/platform")


def load_config(path: str) -> dict:
    value = json.loads(Path(path).read_text())
    validate(value, json.loads(Path("contracts/devops/deployment.schema.json").read_text()))
    network = ipaddress.ip_network(value["sql_cidr"], strict=True)
    if network.version != 4 or network.prefixlen == 0:
        raise ValueError("SQL network must be explicitly scoped IPv4")
    return value


def digest_tree() -> str:
    """Bind plan to source/config/locks/code/ZIP; ignore caches and generated plans."""
    digest = hashlib.sha256()
    roots = ["ci", "infra", "contracts", "config", "pipelines", "sources",
             "transformations", "data_quality", "targets", "orchestration", "pyproject.toml",
             "requirements.lock",
             "requirements-dev.lock", "build/lambda.zip", "build/release.json"]
    paths = []
    for root in roots:
        p = Path(root)
        paths.extend(p.rglob("*") if p.is_dir() else [p])
    for p in sorted(set(paths)):
        if (not p.is_file() or any(x in p.parts for x in [".terraform", "__pycache__"])
                or p.name in {"deployment.auto.tfvars.json", "tfplan", "tfplan.txt"}):
            continue
        digest.update(str(p).encode())
        digest.update(p.read_bytes())
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=["validate", "plan", "apply"])
    parser.add_argument("--config", default="config/deployment.json")
    args = parser.parse_args()
    config = load_config(args.config)
    if config["iac_engine"] != "terraform":
        raise SystemExit("CDK adapter is not implemented; no resources changed")
    if args.operation == "validate":
        print("Deployment contract valid; Terraform adapter selected")
        return
    release = json.loads(Path("build/release.json").read_text())["sha256"]
    actual = hashlib.sha256(Path("build/lambda.zip").read_bytes()).hexdigest()
    if release != actual:
        raise SystemExit("Release artifact hash mismatch")
    required = ["TF_STATE_BUCKET", "TF_STATE_KEY", "TF_STATE_KMS_ARN", "RUNTIME_BOUNDARY_ARN"]
    if any(not os.environ.get(key) for key in required):
        raise SystemExit("Missing protected CodeBuild deployment bindings")
    # One controller/pipeline per tenant; config cannot reroute its protected state.
    prefix = f'{config["project"]}-{config["environment"]}-{config["tenant_id"]}'
    if os.environ["TF_STATE_KEY"] != f"platform/{prefix}/terraform.tfstate":
        raise SystemExit("State key does not match trusted deployment binding")
    boundary = os.environ["RUNTIME_BOUNDARY_ARN"]
    if not re.fullmatch(r"arn:aws:iam::[0-9]{12}:policy/[A-Za-z0-9+=,.@_/-]+", boundary):
        raise SystemExit("Invalid runtime boundary ARN")
    tf = os.environ.get("TERRAFORM", "/tmp/atdp-tools/terraform")

    def run(*parts: str) -> None:
        subprocess.run([tf, f"-chdir={ROOT}", *parts], check=True)

    deployment = {key: val for key, val in config.items()
                  if key not in {"contract_version", "iac_engine"}}
    deployment["release_id"] = release
    deployment["runtime_boundary_arn"] = boundary
    (ROOT / "deployment.auto.tfvars.json").write_text(json.dumps({"deployment": deployment}))
    run("init", "-input=false", "-lockfile=readonly",
        f'-backend-config=bucket={os.environ["TF_STATE_BUCKET"]}',
        f'-backend-config=key={os.environ["TF_STATE_KEY"]}',
        f'-backend-config=region={config["region"]}',
        f'-backend-config=kms_key_id={os.environ["TF_STATE_KMS_ARN"]}',
        "-backend-config=encrypt=true", "-backend-config=use_lockfile=true")
    plan_dir = Path("build/plan")
    if args.operation == "plan":
        plan_dir.mkdir(parents=True, exist_ok=True)
        run("plan", "-input=false", "-lock-timeout=5m", "-out=tfplan")
        shutil.copy2(ROOT / "tfplan", plan_dir / "tfplan")
        with (plan_dir / "tfplan.txt").open("w") as output:
            subprocess.run([tf, f"-chdir={ROOT}", "show", "-no-color", "tfplan"],
                           check=True, stdout=output)
        plan_hash = hashlib.sha256((plan_dir / "tfplan").read_bytes()).hexdigest()
        metadata = {"contract_version": "1", "source_digest": digest_tree(),
                    "plan_sha256": plan_hash, "release": release, "created_at": time.time(),
                    "state_key": os.environ["TF_STATE_KEY"], "boundary": boundary}
        (plan_dir / "metadata.json").write_text(json.dumps(metadata, indent=2))
    else:
        plan_dir = Path(os.environ["CODEBUILD_SRC_DIR_PlanOutput"])
        meta = json.loads((plan_dir / "metadata.json").read_text())
        if (meta["source_digest"] != digest_tree() or meta["release"] != release
                or meta["state_key"] != os.environ["TF_STATE_KEY"] or meta["boundary"] != boundary
                or not 0 <= time.time() - meta["created_at"] <= 86400
                or meta["plan_sha256"] != hashlib.sha256(
                    (plan_dir / "tfplan").read_bytes()).hexdigest()):
            raise SystemExit("Plan/source/state mismatch or plan older than 24h; re-plan required")
        shutil.copy2(plan_dir / "tfplan", ROOT / "tfplan")
        # Apply exactly the approved plan, never re-plan in this job.
        run("apply", "-input=false", "-lock-timeout=5m", "tfplan")
        result = subprocess.run([tf, f"-chdir={ROOT}", "output", "-json", "deployment_contract"],
                                check=True, capture_output=True, text=True)
        Path("build/deployment-output.json").write_text(result.stdout)


if __name__ == "__main__":
    main()
