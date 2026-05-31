#!/usr/bin/env python3
"""Add Ubuntu 24.04 LTS (noble) packaging target to upstream packaging checkout.

The upstream packaging repository does not yet define a noble target. Keep this
patch small and idempotent so local Makefile builds and CI use the same target.
"""

from __future__ import annotations

import sys
from pathlib import Path

NOBLE_BLOCK = """
  noble:
    source: docker/Dockerfile.debian
    args:
      from: ubuntu:noble
      jpeg: libjpeg-turbo8-dev
      python: python3
    output: deb
    matrix: ['amd64', 'arm64', 'armhf', 'ppc64el', 's390x']
    depend: >
      ca-certificates
      fontconfig
      libc6
      libfreetype6
      libjpeg-turbo8
      libpng16-16
      libssl3
      libstdc++6
      libx11-6
      libxcb1
      libxext6
      libxrender1
      xfonts-75dpi
      xfonts-base
      zlib1g

"""


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: patch-packaging-noble.py PACKAGING_DIR", file=sys.stderr)
        return 2

    build_yml = Path(sys.argv[1]) / "build.yml"
    text = build_yml.read_text()
    if "  noble:\n" in text:
        return 0

    marker = "  jammy:\n"
    if marker not in text:
        print(f"{build_yml}: cannot find jammy target marker", file=sys.stderr)
        return 1

    build_yml.write_text(text.replace(marker, NOBLE_BLOCK + marker, 1))
    print(f"patched {build_yml} with noble target")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
