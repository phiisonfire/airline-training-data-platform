"""Pure column mapping/filter for a DQ-validated synthetic snapshot."""
from typing import Any


def map_active(rows: list[dict[str, Any]], tenant_id: str,
               run_id: str) -> list[dict[str, Any]]:
    return [{"tenant_id": tenant_id, "pilot_id": row["source_id"],
             "pilot_name": row["display_name"],
             "employment_date": (row["employmentdate"] if isinstance(row["employmentdate"], str)
                                 else row["employmentdate"].isoformat()),
             "run_id": run_id} for row in rows if row["is_active"]]
