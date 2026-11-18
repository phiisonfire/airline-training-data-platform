"""Strict snapshot checks; no AWS I/O or business qualification semantics."""
from __future__ import annotations

from datetime import date, datetime
from typing import Any


def validate_snapshot(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    issues: list[dict[str, Any]] = []
    seen: set[int] = set()
    required = {"source_id", "display_name", "is_active", "employmentdate"}
    for index, row in enumerate(rows):
        code = None
        if not isinstance(row, dict) or set(row) != required:
            code = "ROW_FIELDS"
        elif type(row["source_id"]) is not int or not 1 <= row["source_id"] <= 2147483647:
            code = "SOURCE_ID_TYPE_OR_RANGE"
        elif row["source_id"] in seen:
            code = "DUPLICATE_SOURCE_ID"
        elif (not isinstance(row["display_name"], str) or not row["display_name"].strip()
              or len(row["display_name"]) > 100):
            code = "DISPLAY_NAME"
        elif type(row["is_active"]) is not bool:
            code = "ACTIVE_TYPE"
        else:
            try:
                hired = row["employmentdate"]
                if isinstance(hired, datetime):
                    raise ValueError
                if isinstance(hired, str):
                    parsed = date.fromisoformat(hired)
                    if parsed.isoformat() != hired:
                        raise ValueError
                elif type(hired) is date:
                    parsed = hired
                else:
                    raise ValueError
            except (ValueError, TypeError):
                code = "EMPLOYMENT_DATE"
        if code:
            issues.append({"row_index": index, "code": code})
            continue
        seen.add(row["source_id"])
    return issues
