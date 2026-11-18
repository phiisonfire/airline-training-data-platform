import pytest

from ci.initialize_state import assert_empty_plan


def test_initialization_allows_only_empty_resource_plan():
    assert_empty_plan({"resource_changes": [], "output_changes": {"backend_initialized": {}}})
    assert_empty_plan({})


@pytest.mark.parametrize("field", ["resource_changes", "resource_drift"])
def test_initialization_refuses_to_destroy_existing_resources(field):
    with pytest.raises(RuntimeError, match="Refusing initialization"):
        assert_empty_plan({field: [{"address": "aws_s3_bucket.data"}]})
