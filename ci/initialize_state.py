"""One-shot owner operation: seed an EMPTY remote backend, never manage resources."""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path

import boto3
from botocore.exceptions import ClientError


def assert_empty_plan(value: dict) -> None:
    if value.get("resource_changes") or value.get("resource_drift"):
        raise RuntimeError("Refusing initialization: the plan contains resource changes/drift")


def main() -> None:
    parser = argparse.ArgumentParser()
    for name in ["bucket", "key", "region", "kms-arn"]:
        parser.add_argument(f"--{name}", required=True)
    args = parser.parse_args()
    client = boto3.client("s3", region_name=args.region)
    try:
        client.head_object(Bucket=args.bucket, Key=args.key)
    except ClientError as exc:
        if exc.response["Error"]["Code"] not in {"NoSuchKey", "404", "NotFound"}:
            raise
    else:
        raise SystemExit("State already exists: no writes performed")
    terraform = os.environ.get("TERRAFORM", "/tmp/atdp-tools/terraform")
    with tempfile.TemporaryDirectory(prefix="atdp-state-init-") as directory:
        Path(directory, "main.tf").write_text(
            'terraform {\n  backend "s3" {}\n}\n'
            'output "backend_initialized" { value = true }\n')

        def run(*parts: str, **kwargs):
            return subprocess.run([terraform, f"-chdir={directory}", *parts], check=True, **kwargs)

        run("init", "-input=false", f"-backend-config=bucket={args.bucket}",
            f"-backend-config=key={args.key}", f"-backend-config=region={args.region}",
            f"-backend-config=kms_key_id={args.kms_arn}", "-backend-config=encrypt=true",
            "-backend-config=use_lockfile=true")
        run("plan", "-input=false", "-lock-timeout=5m", "-out=init.tfplan")
        plan = run("show", "-json", "init.tfplan", capture_output=True, text=True)
        assert_empty_plan(json.loads(plan.stdout))
        run("apply", "-input=false", "-lock-timeout=5m", "init.tfplan")
    print("Initialized empty backend; no data-plane resources created")


if __name__ == "__main__":
    main()
