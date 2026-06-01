#!/usr/bin/env python3
"""Black-box smoke tests for built wkhtmltopdf binaries.

Set WKHTMLTOPDF_BINARY and WKHTMLTOIMAGE_BINARY to test installed binaries.
Otherwise the script prefers build/bin/wkhtmltopdf and build/bin/wkhtmltoimage,
falling back to ./bin for legacy in-source builds.
"""

from __future__ import annotations

import os
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

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

    for candidate in (ROOT / "build" / "bin" / fallback, ROOT / "bin" / fallback):
        if candidate.exists():
            return candidate
    return ROOT / "build" / "bin" / fallback


def runtime_env(*executables: Path) -> dict[str, str]:
    env = os.environ.copy()
    lib_dirs = []
    lib_dirs.extend(exe.parent for exe in executables)
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


def png_info(path: Path) -> tuple[int, int, int, int, bytes]:
    data = path.read_bytes()
    assert_magic(path, PNG_MAGIC)
    if len(data) < 24 or data[12:16] != b"IHDR":
        raise AssertionError(f"{path} is missing a PNG IHDR chunk")

    pos = 8
    width = height = bit_depth = color_type = None
    idat = bytearray()
    while pos + 12 <= len(data):
        chunk_len = struct.unpack(">I", data[pos : pos + 4])[0]
        chunk_type = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + chunk_len]
        pos += 12 + chunk_len
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", chunk
            )
            if bit_depth != 8 or color_type not in (2, 6) or interlace:
                raise AssertionError(
                    f"{path} has unsupported PNG format: bit_depth={bit_depth}, "
                    f"color_type={color_type}, interlace={interlace}"
                )
        elif chunk_type == b"IDAT":
            idat.extend(chunk)
        elif chunk_type == b"IEND":
            break

    if width is None or height is None:
        raise AssertionError(f"{path} is missing PNG metadata")
    return width, height, bit_depth, color_type, bytes(idat)


def assert_png_size(path: Path, width: int, height: int) -> None:
    actual_width, actual_height, _, _, _ = png_info(path)
    if (actual_width, actual_height) != (width, height):
        raise AssertionError(
            f"{path} is {actual_width}x{actual_height}, expected {width}x{height}"
        )


def png_pixel(path: Path, x: int, y: int) -> tuple[int, int, int]:
    width, height, _, color_type, idat = png_info(path)
    if not (0 <= x < width and 0 <= y < height):
        raise AssertionError(f"pixel {x},{y} is outside {path} size {width}x{height}")

    bytes_per_pixel = 3 if color_type == 2 else 4
    stride = width * bytes_per_pixel
    raw = zlib.decompress(idat)
    previous = bytearray(stride)
    offset = 0
    for row_index in range(height):
        filter_type = raw[offset]
        offset += 1
        row = bytearray(raw[offset : offset + stride])
        offset += stride
        for index in range(stride):
            left = row[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
            up = previous[index]
            upper_left = previous[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
            if filter_type == 1:
                row[index] = (row[index] + left) & 0xFF
            elif filter_type == 2:
                row[index] = (row[index] + up) & 0xFF
            elif filter_type == 3:
                row[index] = (row[index] + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                predictor = left + up - upper_left
                pa = abs(predictor - left)
                pb = abs(predictor - up)
                pc = abs(predictor - upper_left)
                if pa <= pb and pa <= pc:
                    paeth = left
                elif pb <= pc:
                    paeth = up
                else:
                    paeth = upper_left
                row[index] = (row[index] + paeth) & 0xFF
            elif filter_type != 0:
                raise AssertionError(f"{path} uses unsupported PNG filter {filter_type}")
        if row_index == y:
            start = x * bytes_per_pixel
            return tuple(row[start : start + 3])
        previous = row

    raise AssertionError(f"pixel {x},{y} was not decoded from {path}")


def main() -> int:
    wkhtmltopdf = binary("WKHTMLTOPDF_BINARY", "wkhtmltopdf")
    wkhtmltoimage = binary("WKHTMLTOIMAGE_BINARY", "wkhtmltoimage")

    env = runtime_env(wkhtmltopdf, wkhtmltoimage)

    for exe in (wkhtmltopdf, wkhtmltoimage):
        if not exe.exists():
            raise FileNotFoundError(f"missing binary: {exe}")
        version = run([exe, "--version"], env)
        version_text = version.stdout.decode(errors="replace").strip()
        print(version_text)
        if "0.13.0" not in version_text:
            raise AssertionError(f"{exe} is not version 0.13.0: {version_text!r}")
        if "(with patched Qt)" not in version_text:
            raise AssertionError(f"{exe} is not a full patched-Qt build: {version_text!r}")

    help_result = run([wkhtmltopdf, "--extended-help"], env)
    help_text = (
        help_result.stdout.decode(errors="replace")
        + help_result.stderr.decode(errors="replace")
    )
    reduced_markers = ("Reduced Functionality", "not using wkhtmltopdf patched Qt")
    for marker in reduced_markers:
        if marker in help_text:
            raise AssertionError(f"{wkhtmltopdf} reports reduced functionality marker: {marker}")

    required_help_text = (
        "NAME:",
        "USAGE:",
        "DESCRIPTION:",
        "full patched-Qt build",
        "headers, footers, outlines",
        "GLOBAL OPTIONS:",
        "PAGE OPTIONS:",
        "--header-html",
        "--footer-html",
        "--outline",
    )
    for marker in required_help_text:
        if marker not in help_text:
            raise AssertionError(f"{wkhtmltopdf} help is incomplete; missing {marker!r}")

    simple = FIXTURES / "simple.html"
    styled = FIXTURES / "styled.html"
    selector = FIXTURES / "selector.html"
    avif = FIXTURES / "avif.html"
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

        if os.environ.get("WKHTMLTOX_AVIF_CONVERTER") or shutil.which("convert") or shutil.which("magick"):
            avif_png = tmpdir / "avif.png"
            run([
                wkhtmltoimage,
                "--quiet",
                "--format",
                "png",
                "--width",
                "64",
                "--height",
                "64",
                avif,
                avif_png,
            ], env)
            red, green, blue = png_pixel(avif_png, 32, 32)
            if red < 120 or green > 80 or blue > 80:
                raise AssertionError(
                    f"{wkhtmltoimage} did not render the AVIF fixture; "
                    f"center pixel is rgb({red}, {green}, {blue})"
                )
        else:
            print("skipping AVIF smoke test: no ImageMagick converter found")

    print("smoke tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
