"""Install a pinned Linux amd64 Terraform, verifying the repository-pinned SHA256."""
import hashlib
import io
import json
import os
from pathlib import Path
from urllib.request import urlopen
from zipfile import ZipFile

if __name__ == "__main__":
    pin = json.loads(Path("ci/terraform-version.json").read_text())
    version = pin["version"]
    url = f"https://releases.hashicorp.com/terraform/{version}/terraform_{version}_linux_amd64.zip"
    with urlopen(url, timeout=120) as response:
        content = response.read()
    if hashlib.sha256(content).hexdigest() != pin["linux_amd64_sha256"]:
        raise SystemExit("Terraform archive checksum mismatch")
    target = Path(os.environ.get("TF_INSTALL_DIR", "/tmp/atdp-tools"))
    target.mkdir(parents=True, exist_ok=True)
    with ZipFile(io.BytesIO(content)) as archive:
        (target / "terraform").write_bytes(archive.read("terraform"))
    (target / "terraform").chmod(0o755)
    print(f"Verified Terraform {version}; installed {target / 'terraform'}")
