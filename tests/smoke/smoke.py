#!/usr/bin/env python3
"""Black-box smoke tests for built wkhtmltopdf binaries.

Set WKHTMLTOPDF_BINARY and WKHTMLTOIMAGE_BINARY to test installed binaries.
Otherwise the script uses ./bin/wkhtmltopdf and ./bin/wkhtmltoimage.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "tests" / "fixtures" / "html"
PDF_MAGIC = b"%PDF-"
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


def binary(env_name: str, fallback: str) -> Path:
    value = os.environ.get(env_name)
    if value:
        resolved = shutil.which(value) if os.sep not in value else value
        if resolved:
            return Path(resolved)
        return Path(value)
    return ROOT / "bin" / fallback


def runtime_env(*executables: Path) -> dict[str, str]:
    env = os.environ.copy()
    lib_dirs = [ROOT / "bin"]
    lib_dirs.extend(exe.parent.parent / "lib" for exe in executables)
    existing = env.get("LD_LIBRARY_PATH")
    if existing:
        lib_dirs.extend(Path(path) for path in existing.split(os.pathsep) if path)
    env["LD_LIBRARY_PATH"] = os.pathsep.join(str(path) for path in lib_dirs if path.exists())
    return env


def run(args: list[Path | str], env: dict[str, str]) -> subprocess.CompletedProcess[bytes]:
    printable = " ".join(str(a) for a in args)
    print(f"+ {printable}")
    return subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, env=env)


def assert_magic(path: Path, magic: bytes) -> None:
    data = path.read_bytes()[: len(magic)]
    if data != magic:
        raise AssertionError(f"{path} has magic {data!r}, expected {magic!r}")


def main() -> int:
    wkhtmltopdf = binary("WKHTMLTOPDF_BINARY", "wkhtmltopdf")
    wkhtmltoimage = binary("WKHTMLTOIMAGE_BINARY", "wkhtmltoimage")

    env = runtime_env(wkhtmltopdf, wkhtmltoimage)

    for exe in (wkhtmltopdf, wkhtmltoimage):
        if not exe.exists():
            raise FileNotFoundError(f"missing binary: {exe}")
        version = run([exe, "--version"], env)
        print(version.stdout.decode(errors="replace").strip())

    simple = FIXTURES / "simple.html"
    styled = FIXTURES / "styled.html"
    header = FIXTURES / "header.html"
    footer = FIXTURES / "footer.html"

    with tempfile.TemporaryDirectory(prefix="wkhtmltox-smoke-") as tmp:
        tmpdir = Path(tmp)

        pdf = tmpdir / "simple.pdf"
        run([wkhtmltopdf, "--quiet", simple, pdf], env)
        assert_magic(pdf, PDF_MAGIC)

        margin_pdf = tmpdir / "header-footer-margin.pdf"
        run([
            wkhtmltopdf,
            "--quiet",
            "--header-html",
            header,
            "--header-margin",
            "2",
            "--footer-html",
            footer,
            "--footer-margin",
            "2",
            styled,
            margin_pdf,
        ], env)
        assert_magic(margin_pdf, PDF_MAGIC)

        png = tmpdir / "styled.png"
        run([wkhtmltoimage, "--quiet", "--format", "png", styled, png], env)
        assert_magic(png, PNG_MAGIC)

    print("smoke tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
