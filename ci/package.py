"""Build immutable x86_64 Python 3.12 Lambda ZIP; no Terraform dependency."""
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


def package() -> None:
    stage = Path("build/package")
    if stage.exists():
        shutil.rmtree(stage)
    stage.mkdir(parents=True)
    subprocess.run([sys.executable, "-m", "pip", "install", "--require-hashes",
                    "--only-binary=:all:", "--platform", "manylinux_2_34_x86_64",
                    "--platform", "manylinux_2_28_x86_64", "--platform", "manylinux2014_x86_64",
                    "--python-version", "3.12", "--implementation", "cp",
                    "--no-compile", "-r", "requirements.lock", "--target", str(stage)], check=True)
    for source in ["pipelines", "sources", "transformations", "data_quality", "targets"]:
        shutil.copytree(source, stage / source,
                        ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "README.md"))
    with ZipFile("build/lambda.zip", "w", compression=ZIP_DEFLATED) as archive:
        for path in sorted(stage.rglob("*")):
            if path.is_file() and "__pycache__" not in path.parts:
                info = ZipInfo(path.relative_to(stage).as_posix(), date_time=(2020, 1, 1, 0, 0, 0))
                info.compress_type = ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                archive.writestr(info, path.read_bytes())
    shutil.rmtree(stage)
    digest = hashlib.sha256(Path("build/lambda.zip").read_bytes()).hexdigest()
    Path("build/release.json").write_text(json.dumps({"contract_version": "1", "sha256": digest},
                                                   indent=2) + "\n")
    print(f"Lambda artifact SHA256: {digest}")


if __name__ == "__main__":
    package()
