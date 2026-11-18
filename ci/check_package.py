"""Verify release hash, source consistency and isolated Linux dependency imports."""
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from zipfile import ZipFile


def main() -> None:
    target = Path("build/lambda.zip")
    expected = json.loads(Path("build/release.json").read_text())["sha256"]
    if hashlib.sha256(target.read_bytes()).hexdigest() != expected:
        raise SystemExit("Artifact digest mismatch")
    with ZipFile(target) as archive:
        for root in ["pipelines", "sources", "transformations", "data_quality", "targets"]:
            for source in Path(root).rglob("*.py"):
                if ("__pycache__" not in source.parts
                        and archive.read(str(source)) != source.read_bytes()):
                    raise SystemExit("Artifact source does not match checked-out code")
        with tempfile.TemporaryDirectory(prefix="atdp-package-check-") as directory:
            archive.extractall(directory)
            script = ("import sys; sys.path.insert(0, sys.argv[1]); "
                      "import boto3, certifi, pytds; from pytds import tls; "
                      "import pipelines.sql_to_s3.handler; "
                      "tls.create_context(certifi.where()); "
                      "print('Package imports/TLS context verified without site-packages')")
            subprocess.run([sys.executable, "-I", "-S", "-c", script, directory], check=True)
    print(f"Artifact source/hash verified: {expected}")


if __name__ == "__main__":
    main()
