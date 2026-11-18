"""Default checks: local logic + syntax + provider-backed offline IaC validation."""
import os
import subprocess
import sys
from pathlib import Path


def run(*command: str) -> None:
    subprocess.run(command, check=True)


if __name__ == "__main__":
    run(sys.executable, "-m", "ruff", "check", ".")
    run(sys.executable, "-m", "pytest", "-q")
    terraform = os.environ.get("TERRAFORM", "/tmp/atdp-tools/terraform")
    run(terraform, "fmt", "-check", "-recursive", "infra/terraform")
    for root in ["bootstrap", "platform", "modules/data_plane"]:
        directory = str(Path("infra/terraform") / root)
        run(terraform, f"-chdir={directory}", "init", "-backend=false", "-input=false",
            "-lockfile=readonly")
        run(terraform, f"-chdir={directory}", "validate")
        run(terraform, f"-chdir={directory}", "test", "-no-color")
