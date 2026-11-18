"""AWS entrypoint. Only safe counts/correlation codes reach application logs."""
from __future__ import annotations

import json
import logging
import os
from typing import Any

from pipelines.sql_to_s3.job import Binding, ContractError, execute

LOG = logging.getLogger(__name__)
LOG.setLevel(logging.INFO)


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    import boto3
    import certifi

    from sources.sqlserver.extract import extract_rows
    from targets.s3.store import S3Store

    binding = Binding(tenant_id=os.environ["TENANT_ID"],
                      source_schema=os.environ["SOURCE_SCHEMA"],
                      source_table=os.environ["SOURCE_TABLE"],
                      release=os.environ["RELEASE_ID"], max_rows=int(os.environ["MAX_ROWS"]))
    try:
        # Input cannot select tenant, secret, table, bucket or arbitrary SQL.
        if set(event) != {"run_id"}:
            raise ContractError("EVENT_CONTRACT")
        store = S3Store(boto3.client("s3"), os.environ["DATA_BUCKET"],
                        binding.tenant_id, os.environ["KMS_KEY_ARN"])

        def extract() -> Any:
            value = boto3.client("secretsmanager").get_secret_value(
                SecretId=os.environ["SOURCE_SECRET_ARN"])
            secret = json.loads(value["SecretString"])
            return extract_rows(binding, secret, os.environ.get("SQL_CA_FILE") or certifi.where())

        result = execute(binding, event["run_id"], store, extract)
    except Exception as exc:
        code = str(exc) if isinstance(exc, ContractError) else "PIPELINE_TECHNICAL_ERROR"
        # No traceback: driver/SDK messages may include host, SQL, payload or credentials.
        LOG.error(json.dumps({"event": "pipeline_failed", "code": code,
                              "request_id": context.aws_request_id}))
        raise RuntimeError(code) from None
    LOG.info(json.dumps({"event": "pipeline_succeeded", "input_count": result["input_count"],
                         "output_count": result["output_count"],
                         "request_id": context.aws_request_id}))
    return {"input_count": result["input_count"], "output_count": result["output_count"]}
