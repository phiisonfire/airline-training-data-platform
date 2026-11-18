import json
from dataclasses import replace
from datetime import date

import pytest

from pipelines.sql_to_s3.job import Binding, ContractError, execute


class MemoryStore:
    def __init__(self):
        self.objects = {}
        self.fail_next_manifest = False

    def read(self, key):
        return self.objects.get(key)

    def put_once(self, key, body):
        if self.fail_next_manifest and key.startswith("manifests/"):
            self.fail_next_manifest = False
            raise OSError("simulated commit crash")
        if key in self.objects and self.objects[key] != body:
            raise ContractError("IMMUTABLE_KEY_CONFLICT")
        self.objects[key] = body


@pytest.fixture
def binding():
    return Binding("airline-a", "devops", "pilot_source", "release-test")


@pytest.fixture
def rows():
    return [{"source_id": 1, "display_name": "Example Pilot", "is_active": True,
             "employmentdate": date(2022, 11, 17)},
            {"source_id": 2, "display_name": "Inactive Pilot", "is_active": False,
             "employmentdate": date(2020, 2, 29)}]


def test_mapping_filter_and_manifest(binding, rows):
    store = MemoryStore()
    result = execute(binding, "run_1", store, lambda: rows)
    assert result["input_count"] == 2 and result["output_count"] == 1
    assert result["filtered_count"] == 1
    assert json.loads(store.objects[result["data_key"]]) == {
        "tenant_id": "airline-a", "run_id": "run_1", "pilot_id": 1,
        "pilot_name": "Example Pilot", "employment_date": "2022-11-17"}
    assert len(json.loads(store.objects["raw/runs/run_1/snapshot.json"])["rows"]) == 2
    assert json.loads(store.objects["manifests/runs/run_1/success.json"]) == result


def test_crash_after_data_before_manifest_reuses_raw(binding, rows):
    store = MemoryStore()
    store.fail_next_manifest = True
    with pytest.raises(OSError):
        execute(binding, "run1", store, lambda: rows)
    assert not any(k.startswith("manifests/") for k in store.objects)
    result = execute(binding, "run1", store, lambda: pytest.fail("SQL must not be reread"))
    before = dict(store.objects)
    assert execute(binding, "run1", store, lambda: []) == result
    assert store.objects == before


@pytest.mark.parametrize("change", [{"tenant_id": "airline-b"}, {"release": "v2"},
                                    {"source_table": "another_table"}])
def test_run_binding_change_fails_closed(binding, rows, change):
    store = MemoryStore()
    execute(binding, "run1", store, lambda: rows)
    with pytest.raises(ContractError, match="RUN_BINDING_CONFLICT"):
        execute(replace(binding, **change), "run1", store, lambda: [])


@pytest.mark.parametrize("field,value", [
    ("source_id", True), ("source_id", 0), ("source_id", "1"), ("source_id", 2147483648),
    ("is_active", 1), ("is_active", None), ("display_name", ""),
    ("display_name", None), ("display_name", "x" * 101), ("employmentdate", "2024-02-30"),
    ("employmentdate", "20240101"), ("employmentdate", None)])
def test_invalid_source_is_raw_but_not_published(binding, rows, field, value):
    rows[0][field] = value
    store = MemoryStore()
    with pytest.raises(ContractError, match="DATA_QUALITY_FAILED"):
        execute(binding, "bad", store, lambda: rows)
    assert "raw/runs/bad/snapshot.json" in store.objects
    assert "quarantine/runs/bad/issues.json" in store.objects
    assert not any(k.startswith(("curated/", "manifests/")) for k in store.objects)


def test_missing_not_same_as_null(binding, rows):
    del rows[0]["is_active"]
    store = MemoryStore()
    with pytest.raises(ContractError):
        execute(binding, "missing", store, lambda: rows)
    issues = json.loads(store.objects["quarantine/runs/missing/issues.json"])
    assert issues[0]["code"] == "ROW_FIELDS"


def test_duplicate_and_invalid_inactive_block_whole_snapshot(binding, rows):
    rows[1]["source_id"] = 1
    with pytest.raises(ContractError):
        execute(binding, "dupe", MemoryStore(), lambda: rows)
    rows[1]["source_id"] = 2
    rows[1]["display_name"] = None
    with pytest.raises(ContractError):
        execute(binding, "inactivebad", MemoryStore(), lambda: rows)


def test_limit_is_not_silent_truncation(binding, rows):
    store = MemoryStore()
    with pytest.raises(ContractError, match="LIMIT"):
        execute(replace(binding, max_rows=1), "large", store, lambda: rows)
    assert not store.objects


def test_empty_snapshot_commits(binding):
    store = MemoryStore()
    result = execute(binding, "empty", store, lambda: [])
    assert result["output_count"] == 0
    assert store.objects[result["data_key"]] == b""


@pytest.mark.parametrize("run_id", ["../airline-b", "x/y", "", "x" * 81])
def test_path_injection_never_extracts(binding, run_id):
    with pytest.raises(ContractError):
        execute(binding, run_id, MemoryStore(), lambda: pytest.fail("must not read"))


def test_sql_identifier_injection_rejected():
    with pytest.raises(ContractError):
        Binding("airline-a", "dbo]; DROP TABLE x;--", "table", "test")
