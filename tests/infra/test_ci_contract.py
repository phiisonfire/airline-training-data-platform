import json
from pathlib import Path

import hcl2
import pytest
import yaml
from jsonschema import ValidationError

from ci.iac import load_config


def config(tmp_path):
    value = json.loads(Path("config/examples/devops-lab.json").read_text())
    value.update(region="us-east-1", vpc_id="vpc-0123456789abcdef0",
                 subnet_ids=["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"],
                 route_table_ids=["rtb-0123456789abcdef0"])
    p = tmp_path / "deployment.json"
    p.write_text(json.dumps(value))
    return p, value


def test_all_terraform_parses():
    for p in Path("infra/terraform").rglob("*.tf"):
        if ".terraform" not in p.parts:
            with p.open() as source:
                assert hcl2.load(source)


def test_deployment_contract_rejects_placeholders_and_cross_scope(tmp_path):
    with pytest.raises(ValidationError):
        load_config("config/examples/devops-lab.json")
    path, value = config(tmp_path)
    assert load_config(str(path))["tenant_id"] == "airline-a"
    value["sql_cidr"] = "0.0.0.0/0"
    path.write_text(json.dumps(value))
    with pytest.raises(ValueError):
        load_config(str(path))
    value["sql_cidr"] = "10.0.0.0/24"
    value["password"] = "must-not-be-configured-here"
    path.write_text(json.dumps(value))
    with pytest.raises(ValidationError):
        load_config(str(path))


def test_buildspecs_have_failure_propagating_commands():
    for stage in ["build", "plan", "apply"]:
        spec = yaml.safe_load(Path(f"ci/codebuild/{stage}.yml").read_text())
        assert spec["version"] == 0.2
        assert spec["phases"]["install"]["runtime-versions"]["python"] == "3.12"
        commands = spec["phases"]["build"]["commands"]
        assert all("|| true" not in c for c in commands)
        expected = f"python ci/iac.py {stage}" if stage != "build" else "python ci/check.py"
        assert expected in commands


def test_cdk_selection_fails_explicitly_not_falls_back(tmp_path, monkeypatch):
    import sys

    from ci.iac import main

    path, value = config(tmp_path)
    value["iac_engine"] = "cdk"
    path.write_text(json.dumps(value))
    monkeypatch.setattr(sys, "argv", ["iac", "validate", "--config", str(path)])
    with pytest.raises(SystemExit, match="CDK adapter is not implemented"):
        main()


def test_lab_network_has_no_peering_or_public_egress():
    with Path("infra/terraform/network/main.tf").open() as source:
        network = hcl2.load(source)
    resources = {}
    for block in network["resource"]:
        for kind, definitions in block.items():
            resources.setdefault(kind.strip('"'), {}).update(
                {name: body for name, body in definitions.items() if name != "__is_block__"})
    assert len(resources["aws_vpc"]) == 1
    assert "for_each" not in next(iter(resources["aws_vpc"].values()))
    assert not {"aws_vpc_peering_connection", "aws_route", "aws_internet_gateway",
                "aws_nat_gateway", "aws_eip"}.intersection(resources)
