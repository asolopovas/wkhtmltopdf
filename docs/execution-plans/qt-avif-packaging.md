# Qt build modes and AVIF packaging plan

## Goal

Clarify patched vs system Qt build modes and make the system-Qt release/development path include AVIF image plugin support.

## Scope

- [x] Keep patched Qt available for legacy full-feature wkhtmltopdf packaging.
- [x] Keep system Qt 5 builds because AVIF depends on Qt 5 image plugin support.
- [x] Add `qt5-avif-image-plugin` as an optional local Qt 5 dependency where the distro provides it.
- [x] Add `qt5-avif-image-plugin` as a required Linux release container dependency so `scripts/build-linux-deb.sh` bundles the plugin and its runtime libraries.
- [x] Document the patched-Qt vs system-Qt tradeoff.

## Acceptance criteria

- [x] Docs explain that patched Qt 4 gives wkhtmltopdf-specific PDF features while system Qt 5 enables distro image plugins such as AVIF.
- [x] Qt 5 dev dependency install attempts `qt5-avif-image-plugin` without breaking older distros where it is unavailable.
- [x] Linux release workflow installs `qt5-avif-image-plugin` before packaging.
- [x] Linux package dependency metadata reflects the libc version of the build base.
- [x] Validation confirms an extracted `qt5-avif-image-plugin` is loaded by `wkhtmltopdf` for `https://3oak.co.uk`.

## Validation log

- [x] YAML parsed for `.github/workflows/release.yml`, `.github/workflows/unpatched.yml`, and `.github/workflows/official.yml`.
- [x] `bash -n scripts/install-dev-deps.sh scripts/build-linux-deb.sh scripts/build-windows-msys2.sh`.
- [x] `./scripts/install-dev-deps.sh --qt 5 --dry-run` includes optional `qt5-avif-image-plugin` installation.
- [x] `docker run --rm ubuntu:24.04 ... apt-get install qt5-avif-image-plugin ... find ... libqavif5.so`.
- [x] Downloaded/extracted `qt5-avif-image-plugin`, ran `QT_PLUGIN_PATH=<extracted>/qt5/plugins QT_DEBUG_PLUGINS=1 build/bin/wkhtmltopdf https://3oak.co.uk ...`, and confirmed `libqavif5.so` loaded. Output PDF was 2.1M vs 1.3M without plugin in this environment.
- [x] `make help`.
- [x] `git diff --check`.

## Progress notes

- 2026-06-01: Confirmed local system has `libavif16` but no Qt AVIF image plugin; `https://3oak.co.uk` contains many `.avif` image URLs.
- 2026-06-01: Confirmed AVIF works through the Qt plugin path by extracting the Ubuntu `qt5-avif-image-plugin` package and observing Qt load `libqavif5.so` during conversion.
- 2026-06-01: Made local AVIF dependency optional so Ubuntu 22.04/system-Qt compatibility checks still run; Linux release packaging remains on Ubuntu 24.04 where the plugin is available.
