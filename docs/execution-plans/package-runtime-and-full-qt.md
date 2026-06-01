# Package runtime and full Qt validation

## Goal
Ship wkhtmltox packages at version 0.13.0 that install cleanly, do not expose private bundled libraries globally, and cannot be produced with reduced-functionality/unpatched Qt.

## Scope
- Linux `.deb` build/test scripts.
- Windows release build guard.
- Smoke/package tests that reject reduced-functionality builds.
- CI release/unpatched workflows so bad artifacts cannot be published.

## Acceptance criteria
- `VERSION` remains `0.13.0`, and Linux Debian packages use epoch `1:` so they upgrade the upstream `1:0.12.6.1-3.bookworm` package cleanly.
- Release builds fail early with a clear error when qmake points at unpatched Qt.
- `wkhtmltopdf --version` for tested artifacts includes `(with patched Qt)` and help does not contain `Reduced Functionality`.
- The `.deb` does not install `/etc/ld.so.conf.d/wkhtmltox.conf` and does not publish `/opt/wkhtmltox/lib/libstdc++.so.6` via `ldconfig`.
- Packaged ELF files have a private runtime path to `/opt/wkhtmltox/lib`.
- Optional AVIF conversion packages are not hard Debian dependencies, so `dpkg -i` can install the `.deb` on hosts without resolving ImageMagick first.
- The Linux `.deb` moves stale `/usr/local/bin/wkhtmltopdf`, `/usr/local/bin/wkhtmltoimage`, and `/usr/local/lib/libwkhtmltox.so*` out of the way and leaves `/usr/local/bin` resolving to the packaged wrappers.
- A small Docker E2E harness proves the `.deb` installs with plain `dpkg -i` in fresh Ubuntu/Debian containers without building wkhtmltopdf or FrankenPHP.
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
- [x] Add AVIF decoding for patched Qt WebKit through ImageMagick-compatible converters.

## Decisions
- Do not hide reduced functionality by changing help text; reject unpatched Qt at build/test time instead.
- Keep the release version pinned to `0.13.0`.
- Use Debian epoch `1:` for Linux `.deb` metadata because the old upstream Bookworm package used epoch `1:` and otherwise `dpkg` treats `0.13.0-1.linux` as a downgrade.
- Keep `/usr/lib/<multiarch>/libwkhtmltox.so*` symlinks for C API compatibility, but rely on ELF RUNPATH for private dependencies instead of global `/opt` ld.so configuration.
- Use ImageMagick as the practical AVIF bridge for Qt 4 WebKit instead of adding a new native codec stack to the forked Qt tree.
- Keep ImageMagick as a Debian `Recommends`, not `Depends`, because AVIF rendering is optional and a hard dependency can make unrelated host installs fail.

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
- 2026-06-01 public release verification: downloaded both `latest` and `0.13.0` GitHub release `.deb` and Windows `.exe` assets; hashes matched (`acf128204c1937580720ebedd3b02935606f6feb9e7d7622e175e44a4f687113` for `.deb`, `bd5533fdc97297a1557734181ae950f25a628330d4679a96b67d005b6993a12b` for `.exe`) and `latest`/`0.13.0` assets were byte-identical.
- 2026-06-01 public release verification: installed downloaded `latest.deb`; plain `wkhtmltopdf --version` and `wkhtmltoimage --version` report `0.13.0 (with patched Qt)`, `wkhtmltopdf https://3oak.co.uk /tmp/wkhtmltox-public-verify/3oak-public.pdf` exited 0 and produced a 5-page PDF, and `WKHTMLTOPDF_BINARY=wkhtmltopdf WKHTMLTOIMAGE_BINARY=wkhtmltoimage python3 tests/smoke/smoke.py` passed.
- 2026-06-01 public release verification: extracted downloaded `latest.exe` with `7z` and verified `bin/wkhtmltopdf.exe` contains `0.13.0 (with patched Qt)`.
- 2026-06-01 quiet HTTPS follow-up: removed noisy benign warnings from the indeterminate-upload fallback and generic ignored SSL subresource handler; rebuilt and installed the Linux `.deb`; `wkhtmltopdf https://3oak.co.uk /tmp/3oak-clean.pdf` exited 0, produced a 5-page PDF, and emitted no `Neither content-length`, `content-type missing`, or `SSL error ignored` warnings.
- 2026-06-01 quiet HTTPS follow-up validation passed: `bash -n scripts/build-linux-deb.sh scripts/build-windows-msys2.sh tests/deb/deb-loader.sh`; `git diff --check`; `python3 -m py_compile tests/smoke/smoke.py`; `shellcheck scripts/build-linux-deb.sh scripts/build-windows-msys2.sh tests/deb/deb-loader.sh`; `WKHTMLTOPDF_BINARY=wkhtmltopdf WKHTMLTOIMAGE_BINARY=wkhtmltoimage python3 tests/smoke/smoke.py`; `tests/deb/deb-loader.sh artifacts/linux-deb/wkhtmltox_0.13.0-1.linux_amd64.deb`.
- 2026-06-01 quiet HTTPS follow-up rebuilt artifact checksums: Linux `.deb` `49ba0be57e79b2fda514626b0f849ca4423f8944e17e6da1969678ed0ecaf9ca`; Windows installer `e49ef82dc074e04fab052471738c90e23006cf448cc36f4b4cdb5f734af3a1bc`.
- 2026-06-01 quiet public release verification: downloaded both `latest` and `0.13.0` GitHub release `.deb` and Windows `.exe` assets; hashes matched (`49ba0be57e79b2fda514626b0f849ca4423f8944e17e6da1969678ed0ecaf9ca` for `.deb`, `e49ef82dc074e04fab052471738c90e23006cf448cc36f4b4cdb5f734af3a1bc` for `.exe`) and `latest`/`0.13.0` assets were byte-identical.
- 2026-06-01 quiet public release verification: installed downloaded `latest.deb`; `wkhtmltopdf https://3oak.co.uk 3oak-public-clean.pdf` exited 0, produced a 5-page PDF, and emitted no `Neither content-length`, `content-type missing`, or `SSL error ignored` warnings.
- 2026-06-01 AVIF follow-up: patched Qt WebKit to recognize `image/avif` and decode static AVIF images by converting them to PNG with `WKHTMLTOX_AVIF_CONVERTER`, `convert`, or `magick`; Linux launches the converter through `/usr/bin/env -u LD_LIBRARY_PATH` so bundled `/opt/wkhtmltox/lib` libraries do not poison ImageMagick.
- 2026-06-01 AVIF follow-up: added ImageMagick to Linux package/dev/CI dependencies and added an AVIF fixture to `tests/smoke/smoke.py` that verifies a rendered red center pixel.
- 2026-06-01 AVIF follow-up validation passed: `bash -n scripts/build-linux-deb.sh scripts/build-windows-msys2.sh tests/deb/deb-loader.sh scripts/install-dev-deps.sh`; `git diff --check`; `python3 -m py_compile tests/smoke/smoke.py`; `shellcheck scripts/build-linux-deb.sh scripts/build-windows-msys2.sh tests/deb/deb-loader.sh scripts/install-dev-deps.sh`; `WKHTMLTOPDF_BINARY=wkhtmltopdf WKHTMLTOIMAGE_BINARY=wkhtmltoimage python3 tests/smoke/smoke.py`; `tests/deb/deb-loader.sh artifacts/linux-deb/wkhtmltox_0.13.0-1.linux_amd64.deb`.
- 2026-06-01 AVIF follow-up: rebuilt and installed the Linux `.deb`; package control now depends on `libc6 (>= 2.31), imagemagick`; `wkhtmltopdf https://3oak.co.uk /tmp/3oak-avif-final.pdf` exited 0 and produced an 819K 8-page PDF in 9.42s locally.
- 2026-06-01 AVIF follow-up rebuilt artifact checksums: Linux `.deb` `656b177465d14c8a88e2bdf5bb33737a5b67962511e2f2706df05e9174d0a172`; Windows installer `8aae400de69006c916c6a6b915308611fab15cf5f18bdffbd094517a2f1ef87d`.
- 2026-06-01 AVIF public release verification: downloaded both `latest` and `0.13.0` GitHub release `.deb` and Windows `.exe` assets; hashes matched (`656b177465d14c8a88e2bdf5bb33737a5b67962511e2f2706df05e9174d0a172` for `.deb`, `8aae400de69006c916c6a6b915308611fab15cf5f18bdffbd094517a2f1ef87d` for `.exe`) and `latest`/`0.13.0` assets were byte-identical.
- 2026-06-01 AVIF public release verification: installed downloaded `latest.deb`; `WKHTMLTOPDF_BINARY=wkhtmltopdf WKHTMLTOIMAGE_BINARY=wkhtmltoimage python3 tests/smoke/smoke.py` passed including the AVIF fixture; `wkhtmltopdf https://3oak.co.uk /tmp/wkhtmltox-avif-public-verify/3oak-public-avif.pdf` exited 0, produced an 819K 8-page PDF, and emitted no `Neither content-length`, `content-type missing`, or `SSL error ignored` warnings.
- 2026-06-01 AVIF public release verification: extracted downloaded `latest.exe` with `7z` and verified `bin/wkhtmltopdf.exe` contains `0.13.0 (with patched Qt)`, `image/avif`, and `WKHTMLTOX_AVIF_CONVERTER`.
- 2026-06-01 dependency follow-up: reproduced the clean Trixie install failure for the previous package: `docker run --rm -v /home/andrius/www/wkhtmltox_0.13.0-1.linux_amd64.deb:/tmp/wkhtmltox.deb:ro debian:trixie-slim sh -eux -c 'dpkg -i /tmp/wkhtmltox.deb'` failed because `wkhtmltox depends on imagemagick; however: Package imagemagick is not installed`.
- 2026-06-01 dependency follow-up: changed Linux package metadata so ImageMagick is a `Recommends`, not a hard `Depends`, and added `tests/deb/deb-loader.sh` coverage to reject hard ImageMagick dependencies.
- 2026-06-01 dependency follow-up validation passed: `bash -n scripts/build-linux-deb.sh tests/deb/deb-loader.sh scripts/install-dev-deps.sh`; `git diff --check`; `shellcheck scripts/build-linux-deb.sh tests/deb/deb-loader.sh scripts/install-dev-deps.sh`; `docker run --rm -v /home/andrius/www/wkhtmltox_0.13.0-1.linux_amd64.deb:/tmp/wkhtmltox.deb:ro debian:trixie-slim sh -eux -c 'dpkg -i /tmp/wkhtmltox.deb && wkhtmltopdf --version'`; `tests/deb/deb-loader.sh /home/andrius/www/wkhtmltox_0.13.0-1.linux_amd64.deb`.
- 2026-06-01 dependency follow-up rebuilt local artifact checksum: Linux `.deb` `f97d65fbcbf7e892f3291af56d87fc315df3be7d7b215024c01221410901c587`; previous hard-ImageMagick artifact was saved as `/home/andrius/www/wkhtmltox_0.13.0-1.linux_amd64.hard-imagemagick.bak.deb` with checksum `656b177465d14c8a88e2bdf5bb33737a5b67962511e2f2706df05e9174d0a172`.
- 2026-06-01 Docker E2E follow-up: added `tests/deb/e2e-docker.sh`, `tests/deb/Dockerfile.e2e`, and `tests/deb/e2e-install-container.sh` to validate a supplied `.deb` in fresh containers with only `dpkg -i` plus version, symlink, stale library, and reduced-functionality assertions.
- 2026-06-01 Docker E2E validation passed for public release asset `c0f9dc53987248e3a24214b0acbee9cfc646a35837942a397ee6a533470350de`: `tests/deb/e2e-docker.sh /tmp/opencode/release-epoch-verify/latest/wkhtmltox_0.13.0-1.linux_amd64.deb` across `ubuntu:20.04`, `ubuntu:22.04`, `ubuntu:24.04`, `debian:bookworm-slim`, and `debian:trixie-slim`.
- 2026-06-01 Docker E2E script validation passed: `bash -n tests/deb/e2e-docker.sh tests/deb/e2e-install-container.sh tests/deb/deb-loader.sh scripts/build-linux-deb.sh`; `shellcheck tests/deb/e2e-docker.sh tests/deb/e2e-install-container.sh tests/deb/deb-loader.sh scripts/build-linux-deb.sh`; `git diff --check`.

## Debt
- A full artifact build requires a patched Qt toolchain. If unavailable locally, CI/release should fail rather than publishing reduced-functionality packages.
