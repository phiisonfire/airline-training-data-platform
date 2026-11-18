"""Small full-snapshot use case; no AWS/SQL dependency in the execution core."""
from __future__ import annotations

import hashlib
import json
import re
from collections.abc import Callable, Iterable
from dataclasses import dataclass
from datetime import date, datetime
from typing import Any, Protocol

from data_quality.simple.pilots import validate_snapshot
from transformations.simple.pilots import map_active


class ContractError(ValueError):
    """Safe code only: never include SQL payload or connection errors."""


class ImmutableStore(Protocol):
    def read(self, key: str) -> bytes | None: ...
    def put_once(self, key: str, body: bytes) -> None: ...


def encode(value: Any) -> bytes:
    def default(item: Any) -> str:
        if isinstance(item, (date, datetime)):
            return item.isoformat()
        raise ContractError("UNSUPPORTED_SOURCE_TYPE")

    return json.dumps(value, default=default, sort_keys=True, ensure_ascii=False,
                      separators=(",", ":"), allow_nan=False).encode("utf-8")


@dataclass(frozen=True)
class Binding:
    tenant_id: str
    source_schema: str
    source_table: str
    release: str
    max_rows: int = 10000

    def __post_init__(self) -> None:
        if not re.fullmatch(r"[a-z][a-z0-9-]{1,31}", self.tenant_id):
            raise ContractError("INVALID_TENANT")
        for name in (self.source_schema, self.source_table):
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,127}", name):
                raise ContractError("INVALID_IDENTIFIER")
        if not self.release or not 1 <= self.max_rows <= 100000:
            raise ContractError("INVALID_BINDING")

    def fingerprint(self) -> str:
        return hashlib.sha256(encode(self.__dict__)).hexdigest()


def execute(binding: Binding, run_id: str, store: ImmutableStore,
            extract: Callable[[], Iterable[dict[str, Any]]]) -> dict[str, Any]:
    """Retry one run from immutable raw; never reread mutable SQL after raw commit."""
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", run_id):
        raise ContractError("INVALID_RUN_ID")
    base = f"runs/{run_id}"
    raw_key = f"raw/{base}/snapshot.json"
    existing = store.read(raw_key)
    if existing is None:
        rows = []
        for row in extract():
            rows.append(row)
            if len(rows) > binding.max_rows:
                raise ContractError("SNAPSHOT_LIMIT_EXCEEDED")
        raw = {"binding": binding.fingerprint(), "rows": rows}
        store.put_once(raw_key, encode(raw))
    else:
        raw = json.loads(existing)
    if raw["binding"] != binding.fingerprint():
        raise ContractError("RUN_BINDING_CONFLICT")

    issues = validate_snapshot(raw["rows"])
    if issues:
        # Quarantine carries safe row indexes/error codes; raw remains tenant-bound.
        store.put_once(f"quarantine/{base}/issues.json", encode(issues))
        raise ContractError("DATA_QUALITY_FAILED")
    mapped = map_active(raw["rows"], binding.tenant_id, run_id)
    data = b"".join(encode(row) + b"\n" for row in mapped)
    data_key = f"curated/pilots/run_id={run_id}/data.jsonl"
    store.put_once(data_key, data)
    result = {"tenant_id": binding.tenant_id, "run_id": run_id,
              "input_count": len(raw["rows"]), "output_count": len(mapped),
              "filtered_count": len(raw["rows"]) - len(mapped),
              "data_key": data_key, "sha256": hashlib.sha256(data).hexdigest(),
              "release": binding.release, "binding": binding.fingerprint()}
    # Manifest is the publication marker, written only after all valid data is durable.
    store.put_once(f"manifests/{base}/success.json", encode(result))
    return result
