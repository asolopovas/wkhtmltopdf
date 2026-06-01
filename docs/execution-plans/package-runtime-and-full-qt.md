# Package runtime and full Qt validation

## Goal
Ship wkhtmltox packages at version 0.13.0 that install cleanly, do not expose private bundled libraries globally, and cannot be produced with reduced-functionality/unpatched Qt.

## Scope
- Linux `.deb` build/test scripts.
- Windows release build guard.
- Smoke/package tests that reject reduced-functionality builds.
- CI release/unpatched workflows so bad artifacts cannot be published.

## Acceptance criteria
- `VERSION` remains `0.13.0`.
- Release builds fail early with a clear error when qmake points at unpatched Qt.
- `wkhtmltopdf --version` for tested artifacts includes `(with patched Qt)` and help does not contain `Reduced Functionality`.
- The `.deb` does not install `/etc/ld.so.conf.d/wkhtmltox.conf` and does not publish `/opt/wkhtmltox/lib/libstdc++.so.6` via `ldconfig`.
- Packaged ELF files have a private runtime path to `/opt/wkhtmltox/lib`.
- Package tests cover direct `/opt` execution, `/usr/bin` wrapper execution, stale `/usr/local/lib/libwkhtmltox.so.0` shadowing, and smoke rendering.
- Build and compilation output is tee'd into git-ignored `tmp/logs/` files for later review, and CI uploads those logs as artifacts on every release job run.

## Progress
- [x] Investigated reported GLIBCXX failure and reduced-functionality output.
- [x] Add hard unpatched-Qt build guards.
- [x] Harden Debian package runtime linking.
- [x] Add package loader tests and wire them into release tests.
- [x] Update CI workflows to block unpatched artifacts.
- [x] Run closest local checks and record results.

## Decisions
- Do not hide reduced functionality by changing help text; reject unpatched Qt at build/test time instead.
- Keep the release version pinned to `0.13.0`.
- Keep `/usr/lib/<multiarch>/libwkhtmltox.so*` symlinks for C API compatibility, but rely on ELF RUNPATH for private dependencies instead of global `/opt` ld.so configuration.

## Validation
- `bash -n scripts/build-linux-deb.sh scripts/build-windows-msys2.sh tests/deb/deb-loader.sh scripts/install-dev-deps.sh` passed.
- `git diff --check` passed.
- `shellcheck scripts/build-linux-deb.sh scripts/build-windows-msys2.sh tests/deb/deb-loader.sh` passed.
- `python3 -m py_compile tests/smoke/smoke.py` passed.
- `RELEASE_OUTPUT=/tmp/wkhtmltox-guard-test scripts/build-linux-deb.sh` with system Qt 5 failed as expected with: `without the wkhtmltopdf Qt patches`.
- `QMAKE=/usr/bin/qmake scripts/build-windows-msys2.sh` failed as expected with: `without the wkhtmltopdf Qt patches`.
- Verified failed Linux/Windows build attempts create reviewable logs under `tmp/logs/build-linux-deb-*.log` and `tmp/logs/build-windows-msys2-*.log`; `tmp/` is git-ignored.
- `make build QT=5 AUTO_DEPS=0 BUILD_DIR=/tmp/wkhtmltox-unpatched-build BUILD_JOBS=2` failed as expected at `src/lib/converter.cc` with the patched-Qt requirement.
- `WKHTMLTOPDF_BINARY=build/bin/wkhtmltopdf WKHTMLTOIMAGE_BINARY=build/bin/wkhtmltoimage LD_LIBRARY_PATH=$PWD/build/bin:/usr/lib/x86_64-linux-gnu python3 tests/smoke/smoke.py` failed as expected for the old reduced-functionality binary because `--version` did not include `(with patched Qt)`.
- Downloaded the published broken `wkhtmltox_0.13.0-1.linux_amd64.deb`; `tests/deb/deb-loader.sh /tmp/wkhtmltox_0.13.0-1.linux_amd64.deb` failed as expected with `package must not globally publish /opt/wkhtmltox/lib via /etc/ld.so.conf.d/wkhtmltox.conf`.
- Confirmed the installed broken package had poisoned the host loader cache (`ldconfig -p` showed `/opt/wkhtmltox/lib/liblzma.so.5` and `/opt/wkhtmltox/lib/libstdc++.so.6`); removed the stale `/etc/ld.so.conf.d/wkhtmltox.conf` locally and reran `ldconfig` so Debian tooling works again.
- Tried full patched-Qt e2e builds through `wkhtmltopdf/packaging` (`buster-amd64`, `bullseye-amd64`, `bookworm-amd64`, `focal-amd64`). Buster is EOL in upstream Docker apt sources; bullseye had transient DNS/package-index failure; bookworm/focal reached Qt compilation but failed in Qt GUI generated UI code before producing a patched Qt toolchain. No reduced-functionality artifact was produced.
- Full `.deb` install/render validation is now enforced by `tests/deb/deb-loader.sh` plus `tests/smoke/smoke.py`; it requires a package built with a patched Qt qmake.

## Debt
- A full artifact build requires a patched Qt toolchain. If unavailable locally, CI/release should fail rather than publishing reduced-functionality packages.
