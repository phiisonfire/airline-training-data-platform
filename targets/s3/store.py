"""Conditional immutable writes; different payload at the same key is a conflict."""
from __future__ import annotations

import hashlib
from typing import Any

from botocore.exceptions import ClientError

from pipelines.sql_to_s3.job import ContractError


class S3Store:
    def __init__(self, client: Any, bucket: str, tenant_id: str, kms_key: str) -> None:
        self.client, self.bucket, self.kms_key = client, bucket, kms_key
        self.prefix = f"tenant={tenant_id}/"

    def read(self, key: str) -> bytes | None:
        try:
            response = self.client.get_object(Bucket=self.bucket, Key=self.prefix + key)
        except ClientError as exc:
            if exc.response["Error"]["Code"] in {"NoSuchKey", "404"}:
                return None
            raise
        body = response["Body"]
        try:
            return body.read()
        finally:
            body.close()

    def put_once(self, key: str, body: bytes) -> None:
        try:
            self.client.put_object(Bucket=self.bucket, Key=self.prefix + key, Body=body,
                                   ContentType="application/x-ndjson" if key.endswith("jsonl")
                                   else "application/json", IfNoneMatch="*",
                                   ServerSideEncryption="aws:kms", SSEKMSKeyId=self.kms_key,
                                   Metadata={"sha256": hashlib.sha256(body).hexdigest()})
        except ClientError as exc:
            if exc.response["Error"]["Code"] not in {"PreconditionFailed", "412"}:
                raise
            if self.read(key) != body:
                raise ContractError("IMMUTABLE_KEY_CONFLICT") from None
