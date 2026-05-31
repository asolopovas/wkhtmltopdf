#!/usr/bin/env python3
"""Black-box smoke tests for built wkhtmltopdf binaries.

Set WKHTMLTOPDF_BINARY and WKHTMLTOIMAGE_BINARY to test installed binaries.
Otherwise the script uses ./bin/wkhtmltopdf and ./bin/wkhtmltoimage.
"""

from __future__ import annotations

import os
import shutil
import struct
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
    lib_dirs = []
    lib_dirs.extend(exe.parent for exe in executables)
    lib_dirs.append(ROOT / "bin")
    lib_dirs.extend(exe.parent.parent / "lib" for exe in executables)
    existing = env.get("LD_LIBRARY_PATH")
    if existing:
        lib_dirs.extend(Path(path) for path in existing.split(os.pathsep) if path)
    env["LD_LIBRARY_PATH"] = os.pathsep.join(str(path) for path in lib_dirs if path.exists())
    return env


def run(
    args: list[Path | str],
    env: dict[str, str],
    pass_fds: tuple[int, ...] = (),
    input_data: bytes | None = None,
) -> subprocess.CompletedProcess[bytes]:
    printable = " ".join(str(a) for a in args)
    print(f"+ {printable}")
    return subprocess.run(
        args,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
        env=env,
        pass_fds=pass_fds,
        input=input_data,
    )


def assert_magic(path: Path, magic: bytes) -> None:
    data = path.read_bytes()[: len(magic)]
    if data != magic:
        raise AssertionError(f"{path} has magic {data!r}, expected {magic!r}")


def assert_png_size(path: Path, width: int, height: int) -> None:
    data = path.read_bytes()
    assert_magic(path, PNG_MAGIC)
    if len(data) < 24 or data[12:16] != b"IHDR":
        raise AssertionError(f"{path} is missing a PNG IHDR chunk")
    actual_width, actual_height = struct.unpack(">II", data[16:24])
    if (actual_width, actual_height) != (width, height):
        raise AssertionError(
            f"{path} is {actual_width}x{actual_height}, expected {width}x{height}"
        )


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
    selector = FIXTURES / "selector.html"
    header = FIXTURES / "header.html"
    footer = FIXTURES / "footer.html"

    with tempfile.TemporaryDirectory(prefix="wkhtmltox-smoke-") as tmp:
        tmpdir = Path(tmp)

        pdf = tmpdir / "simple.pdf"
        run([wkhtmltopdf, "--quiet", simple, pdf], env)
        assert_magic(pdf, PDF_MAGIC)

        unicode_html = tmpdir / "unicode-\u0105.html"
        unicode_pdf = tmpdir / "unicode-\u0105.pdf"
        shutil.copyfile(simple, unicode_html)
        run([wkhtmltopdf, "--quiet", unicode_html, unicode_pdf], env)
        assert_magic(unicode_pdf, PDF_MAGIC)

        margin_pdf = tmpdir / "header-footer-margin.pdf"
        run([
            wkhtmltopdf,
            "--quiet",
            "--header-html",
            header,
            "--header-right",
            "Page [page_roman]/[topage_roman]",
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

        source_header = """
<!doctype html><html><body style='margin:0;font-size:8pt'>
  Source header <span class='page'></span>/<span class='topage'></span>
</body></html>
""".strip()
        source_footer = """
<!doctype html><html><body style='margin:0;font-size:8pt'>
  Source footer
</body></html>
""".strip()
        source_pdf = tmpdir / "header-footer-source.pdf"
        run([
            wkhtmltopdf,
            "--quiet",
            "--header-html-source",
            source_header,
            "--footer-html-source",
            source_footer,
            simple,
            source_pdf,
        ], env)
        assert_magic(source_pdf, PDF_MAGIC)

        if Path("/proc/self/fd").exists():
            read_fd, write_fd = os.pipe()
            try:
                os.write(write_fd, source_header.encode())
                os.close(write_fd)
                write_fd = -1
                fd_pdf = tmpdir / "header-footer-fd.pdf"
                run([
                    wkhtmltopdf,
                    "--quiet",
                    "--header-html",
                    f"/proc/self/fd/{read_fd}",
                    simple,
                    fd_pdf,
                ], env, pass_fds=(read_fd,))
                assert_magic(fd_pdf, PDF_MAGIC)
            finally:
                if write_fd != -1:
                    os.close(write_fd)
                os.close(read_fd)

        png = tmpdir / "styled.png"
        run([wkhtmltoimage, "--quiet", "--format", "png", styled, png], env)
        assert_magic(png, PNG_MAGIC)

        selector_png = tmpdir / "selector.png"
        run([
            wkhtmltoimage,
            "--quiet",
            "--format",
            "png",
            "--selector",
            "#target",
            selector,
            selector_png,
        ], env)
        assert_png_size(selector_png, 120, 80)

        base_url_png = tmpdir / "base-url.png"
        stdin_html = b"""
<!doctype html>
<html>
  <head><link rel="stylesheet" href="base-url.css" /></head>
  <body><div id="target"></div></body>
</html>
""".strip()
        run([
            wkhtmltoimage,
            "--quiet",
            "--format",
            "png",
            "--base-url",
            FIXTURES.as_uri() + "/",
            "--selector",
            "#target",
            "-",
            base_url_png,
        ], env, input_data=stdin_html)
        assert_png_size(base_url_png, 64, 32)

    print("smoke tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
