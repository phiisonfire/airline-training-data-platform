"""Post-deploy control-plane verification. Does NOT query SQL or execute the pipeline."""
import base64
import json
import os
from pathlib import Path

import boto3


def main() -> None:
    directory = Path(os.environ["CODEBUILD_SRC_DIR_DeployOutput"])
    output = json.loads((directory / "deployment-output.json").read_text())
    config = json.loads(Path("config/deployment.json").read_text())
    region = config["region"]
    if output["contract_version"] != "1" or output["tenant_id"] != config["tenant_id"]:
        raise SystemExit("Deployment output binding mismatch")
    function = boto3.client("lambda", region_name=region).get_function_configuration(
        FunctionName=output["worker_alias_arn"])
    expected_hash = base64.b64encode(bytes.fromhex(output["release_id"])).decode()
    if function["CodeSha256"] != expected_hash or function["State"] != "Active":
        raise SystemExit("Published Lambda does not match the approved release or is not active")
    workflow = boto3.client("stepfunctions", region_name=region).describe_state_machine(
        stateMachineArn=output["workflow_arn"])
    if workflow["status"] != "ACTIVE":
        raise SystemExit("Workflow is not ACTIVE")
    secret = boto3.client("secretsmanager", region_name=region).describe_secret(
        SecretId=output["source_secret_arn"])
    print(json.dumps({"event": "deployment_verified", "release": output["release_id"],
                      "source_secret_has_version": bool(secret.get("VersionIdsToStages")),
                      "sql_connectivity": "UNVERIFIED", "data_correctness": "UNVERIFIED"}))


if __name__ == "__main__":
    main()
