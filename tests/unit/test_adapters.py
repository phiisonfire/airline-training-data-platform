from datetime import date
from io import BytesIO
from unittest.mock import MagicMock

import boto3
import pytest
from botocore.stub import Stubber

from pipelines.sql_to_s3.job import Binding, ContractError
from sources.sqlserver.extract import extract_rows
from targets.s3.store import S3Store


def test_sql_secret_binding_before_connection():
    connect = MagicMock()
    secret = {"tenant_id": "airline-b", "host": "sql.example.test", "port": 1433,
              "database": "lab", "username": "synthetic", "password": "synthetic-only"}
    with pytest.raises(ContractError, match="BINDING"):
        list(extract_rows(Binding("airline-a", "devops", "pilot_source", "test"),
                          secret, "ca.pem", connect))
    connect.assert_not_called()


def test_sql_tls_bounded_query_and_lifecycle():
    connect = MagicMock()
    conn = connect.return_value.__enter__.return_value
    cursor = conn.cursor.return_value.__enter__.return_value
    cursor.fetchmany.side_effect = [[{"source_id": 1, "display_name": "Synthetic",
                                     "is_active": True, "employmentdate": date(2020, 1, 1)}], []]
    secret = {"tenant_id": "airline-a", "host": "sql.example.test", "port": 1433,
              "database": "lab", "username": "synthetic", "password": "synthetic-only"}
    assert len(list(extract_rows(Binding("airline-a", "devops", "pilot_source", "test", 3),
                                secret, "ca.pem", connect))) == 1
    options = connect.call_args.kwargs
    assert options["validate_host"] is True and options["enc_login_only"] is False
    assert options["cafile"] == "ca.pem"
    assert "TOP (4)" in cursor.execute.call_args.args[0]
    conn.cursor.return_value.__exit__.assert_called_once()
    connect.return_value.__exit__.assert_called_once()


def client():
    return boto3.client("s3", region_name="us-east-1", aws_access_key_id="synthetic",
                        aws_secret_access_key="synthetic")


def test_s3_replay_same_payload_and_prefix():
    s3 = client()
    store = S3Store(s3, "test-bucket", "airline-a", "key-test")
    with Stubber(s3) as stub:
        stub.add_client_error("put_object", service_error_code="PreconditionFailed",
                              http_status_code=412)
        stub.add_response("get_object", {"Body": BytesIO(b"same")},
                          {"Bucket": "test-bucket", "Key": "tenant=airline-a/raw/test.json"})
        store.put_once("raw/test.json", b"same")
        stub.assert_no_pending_responses()


def test_s3_replay_different_payload_conflicts():
    s3 = client()
    with Stubber(s3) as stub:
        stub.add_client_error("put_object", service_error_code="PreconditionFailed",
                              http_status_code=412)
        stub.add_response("get_object", {"Body": BytesIO(b"old")})
        with pytest.raises(ContractError, match="CONFLICT"):
            S3Store(s3, "test-bucket", "airline-a", "key-test").put_once("raw/x", b"new")


def test_access_denied_is_not_missing():
    s3 = client()
    with Stubber(s3) as stub:
        stub.add_client_error("get_object", service_error_code="AccessDenied", http_status_code=403)
        with pytest.raises(Exception, match="AccessDenied"):
            S3Store(s3, "test-bucket", "airline-a", "key-test").read("raw/x")
