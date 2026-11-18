"""Offline end-to-end demo with synthetic source rows; no AWS or SQL connection."""
import json
from pathlib import Path

from pipelines.sql_to_s3.job import Binding, ContractError, execute


class LocalStore:
    def __init__(self, root: Path) -> None:
        self.root = root

    def read(self, key: str) -> bytes | None:
        path = self.root / key
        return path.read_bytes() if path.exists() else None

    def put_once(self, key: str, body: bytes) -> None:
        path = self.root / key
        path.parent.mkdir(parents=True, exist_ok=True)
        try:
            with path.open("xb") as output:
                output.write(body)
        except FileExistsError:
            if path.read_bytes() != body:
                raise ContractError("IMMUTABLE_KEY_CONFLICT") from None


def main() -> None:
    rows = [{"source_id": 1, "display_name": "Example Pilot A", "is_active": True,
             "employmentdate": "2022-11-17"},
            {"source_id": 2, "display_name": "Example Pilot B", "is_active": False,
             "employmentdate": "2020-02-29"}]
    binding = Binding("airline-a", "devops", "pilot_source", "offline-demo-v1")
    store = LocalStore(Path("build/local/tenant=airline-a"))
    result = execute(binding, "offline_run_1", store, lambda: rows)

    def no_reread():
        raise AssertionError("Retry must reuse committed raw")

    assert execute(binding, "offline_run_1", store, no_reread) == result
    print(json.dumps({"event": "local_demo_passed", "input_count": result["input_count"],
                      "output_count": result["output_count"], "replay": "unchanged",
                      "aws_sql_integration": "NOT_RUN"}))


if __name__ == "__main__":
    main()
