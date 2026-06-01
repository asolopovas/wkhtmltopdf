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
- [x] Fix CLI/man text output so patched builds print complete man-style help instead of truncated first-word paragraphs.
- [x] Build replacement Linux `.deb` and Windows installer artifacts for 0.13.0.
- [x] Fix Qt 4/OpenSSL 1.1 HTTPS rendering failure and JavaScript-triggered indeterminate upload aborts.

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

- 2026-06-01 follow-up: fixed text/html/man outputters to keep encoded strings alive and to avoid Qt4 `foreach` truncation in generated help. Regenerated `docs/usage/wkhtmltopdf.txt` from the patched installed binary.
- 2026-06-01 follow-up: `docker run ... ubuntu:20.04 ... QMAKE=/tgt/qt/bin/qmake RELEASE_OUTPUT=artifacts RELEASE_SERIES=linux scripts/build-linux-deb.sh` produced `artifacts/linux-deb/wkhtmltox_0.13.0-1.linux_amd64.deb`.
- 2026-06-01 follow-up: `tests/deb/deb-loader.sh artifacts/linux-deb/wkhtmltox_0.13.0-1.linux_amd64.deb` passed.
- 2026-06-01 follow-up: `WKHTMLTOPDF_BINARY=/usr/bin/wkhtmltopdf WKHTMLTOIMAGE_BINARY=/usr/bin/wkhtmltoimage python3 tests/smoke/smoke.py` passed and now checks complete patched help markers.
- 2026-06-01 follow-up: rebuilt the Windows MXE package from the patched Qt cache, then created `artifacts/windows-exe/wkhtmltox-0.13.0-1.windows-mxe-cross-win64-installer.exe` with NSIS.
- 2026-06-01 follow-up: extracted the Windows installer with `7z` and verified `bin/wkhtmltopdf.exe` contains `0.13.0 (with patched Qt)` plus the new full patched-Qt description.
- 2026-06-01 follow-up: force-updated `0.13.0` and `latest` tags to commit `f0b8f49f`, uploaded replacement `.deb`, Windows installer, and checksum assets to both GitHub releases with `gh release upload --clobber`.
- 2026-06-01 follow-up: downloaded the `latest` release `.deb`, extracted it, and verified direct `wkhtmltopdf.bin --version` plus clean man-style help with no reduced-functionality markers.
- 2026-06-01 follow-up: downloaded the `latest` release Windows installer, verified checksum `c7ee26c39f95e5f61e0f46c48da1bf92cc42abd771e8cb947a383c701ec3f48f`, extracted it with `7z`, and verified `bin/wkhtmltopdf.exe` contains `(with patched Qt)` and the full patched-Qt description.
- 2026-06-01 follow-up: downloaded `https://github.com/asolopovas/wkhtmltopdf/releases/download/latest/wkhtmltox_0.13.0-1.linux_amd64.deb` and confirmed the package payload was patched, but the default command still resolved to stale `/usr/local/bin` binaries.
- 2026-06-01 follow-up: changed Linux postinst to move shadowing `/usr/local/bin/wkhtmltopdf`, `/usr/local/bin/wkhtmltoimage`, and `/usr/local/lib/libwkhtmltox.so*` aside, then link `/usr/local/bin` commands to `/usr/bin` wrappers.
- 2026-06-01 follow-up: rebuilt the `.deb`, installed it over the stale-local environment, and verified plain `wkhtmltopdf --version` and `wkhtmltoimage --version` both report `(with patched Qt)`.
- 2026-06-01 follow-up: `WKHTMLTOPDF_BINARY=wkhtmltopdf WKHTMLTOIMAGE_BINARY=wkhtmltoimage python3 tests/smoke/smoke.py` passed using default PATH resolution through `/usr/local/bin` symlinks.
- 2026-06-01 follow-up: `tests/deb/deb-loader.sh artifacts/linux-deb/wkhtmltox_0.13.0-1.linux_amd64.deb` passed for rebuilt artifact `90eec4104d125b069cfb594b3e075214150a1bba808940a989adc9689a625c5e`.
- 2026-06-01 follow-up: patched Qt Network so OpenSSL 1.1 TLS 1.3 cipher names do not make `SSL_CTX_set_cipher_list()` fail all HTTPS requests; if Qt's generated cipher list is rejected, it falls back to OpenSSL `DEFAULT`.
- 2026-06-01 follow-up: patched Qt Network to warn and use `Content-Length: 0` instead of `qFatal()` when page JavaScript creates an upload body with unknown size and no explicit content length.
- 2026-06-01 follow-up: rebuilt Linux `.deb` from the updated patched Qt cache and installed it locally; `wkhtmltopdf https://3oak.co.uk /tmp/3oak-validation.pdf` exited 0 and produced a 5-page PDF.
- 2026-06-01 follow-up: rebuilt the Windows MXE installer after Qt Network recompiled `qsslsocket_openssl.cpp` and `qhttpnetworkconnection.cpp`.
- 2026-06-01 follow-up validation passed: `bash -n scripts/build-linux-deb.sh scripts/build-windows-msys2.sh tests/deb/deb-loader.sh`; `git diff --check`; `python3 -m py_compile tests/smoke/smoke.py`; `shellcheck scripts/build-linux-deb.sh scripts/build-windows-msys2.sh tests/deb/deb-loader.sh`; `WKHTMLTOPDF_BINARY=wkhtmltopdf WKHTMLTOIMAGE_BINARY=wkhtmltoimage python3 tests/smoke/smoke.py`.
- 2026-06-01 follow-up rebuilt artifact checksums: Linux `.deb` `acf128204c1937580720ebedd3b02935606f6feb9e7d7622e175e44a4f687113`; Windows installer `bd5533fdc97297a1557734181ae950f25a628330d4679a96b67d005b6993a12b`.

## Debt
- A full artifact build requires a patched Qt toolchain. If unavailable locally, CI/release should fail rather than publishing reduced-functionality packages.
