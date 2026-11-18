"""Bounded SELECT using encrypted TDS and a SELECT-only source principal."""
from __future__ import annotations

from collections.abc import Iterator
from typing import Any

from pipelines.sql_to_s3.job import Binding, ContractError


def extract_rows(binding: Binding, secret: dict[str, Any], cafile: str,
                 connect: Any = None) -> Iterator[dict[str, Any]]:
    # The secret repeats tenant ownership; source rows cannot override routing.
    required = {"tenant_id", "host", "port", "database", "username", "password"}
    if set(secret) != required or secret["tenant_id"] != binding.tenant_id:
        raise ContractError("SECRET_BINDING_MISMATCH")
    if (type(secret["port"]) is not int or not 1 <= secret["port"] <= 65535
            or any(not isinstance(secret[k], str) or not secret[k]
                   for k in required - {"port"})):
        raise ContractError("SECRET_CONTRACT")
    if connect is None:
        import pytds
        connect = pytds.connect
    # Identifiers validated by Binding; values/credentials never interpolate into SQL.
    sql = (f"SELECT TOP ({binding.max_rows + 1}) [source_id], [display_name], "
           f"[is_active], [employmentdate] FROM [{binding.source_schema}]."
           f"[{binding.source_table}] ORDER BY [source_id]")
    with connect(server=secret["host"], database=secret["database"],
                 user=secret["username"], password=secret["password"],
                 port=secret["port"], cafile=cafile, validate_host=True,
                 enc_login_only=False, login_timeout=10, timeout=60,
                 as_dict=True, autocommit=True) as conn:
        with conn.cursor() as cursor:
            cursor.execute(sql)
            while batch := cursor.fetchmany(500):
                yield from batch
