---
layout: default
title: Source guide
---

# Source guide

Maintainer map. Generated CLI/C API docs remain the closest reference for runtime behavior.

## Code map

- `src/shared/` — CLI parsing, option handlers, help output, progress, console feedback.
- `src/lib/` — settings, loading, rendering, output, logging, temp files, C API.
- `src/pdf/` — `wkhtmltopdf`: PDF arguments, objects, outlines, headers/footers, TOC.
- `src/image/` — `wkhtmltoimage`: image arguments, viewport, crop, transparency, formats.
- `src/lib/pdf.h`, `src/lib/image.h` — public C API headers.
- `docs/usage/`, `docs/libwkhtmltox/` — generated references.
- Packaging — local `make release-build` targets and package scripts under `scripts/`.

## Workflow

Use the wrapper unless reproducing raw qmake behavior. `make build` builds locally with the configured qmake. Release package scripts build one Linux `.deb` and one Windows installer, validate that artifacts report `(with patched Qt)`, and reject reduced-functionality packages.

```sh
make           # build the Linux .deb inside Docker
make test      # build and run Linux package checks
make install PREFIX="$HOME/.local"
make install PREFIX=/usr/local # uses sudo when /usr/local is not writable
make clean     # keep configuration
make distclean # remove build dir
```

Useful build knobs: `JOBS=8`, `PATCHED_QT_DIR=/path/to/patched-qt-build-root`, `DOCKER_IMAGE=registry/name:tag`, `DESTDIR=/tmp/package`, `PREFIX=/usr`.

Release preview:

```sh
make release DRY_RUN=1
make release VERSION=0.13.0 PUSH=0
make release BUMP=patch  # build Linux .deb + Windows installer, then upload
```

## Conversion flow

1. CLI/C API populates settings.
2. `MultipageLoader` loads pages/resources.
3. Qt WebKit renders `QWebPage`.
4. `PdfConverter` or `ImageConverter` writes output.
5. `Converter` reports progress, warnings, errors, and completion.

## Hot paths

- PDF CLI: `src/pdf/pdfarguments.cc`, `src/pdf/pdfcommandlineparser.*`.
- PDF settings/rendering: `src/lib/pdfsettings.*`, `src/lib/pdfconverter.*`.
- Image CLI: `src/image/imagearguments.cc`, `src/image/imagecommandlineparser.*`.
- Image settings/rendering: `src/lib/imagesettings.*`, `src/lib/imageconverter.*`.
- Loading/security: `src/lib/loadsettings.*`, `src/lib/reflect.*`, `src/shared/commonarguments.cc`.

Do not publish release artifacts unless package validation proves `(with patched Qt)` and no `Reduced Functionality` help text.

## Change rules

- Loading changes are security-sensitive: review filesystem, network, credentials, cookies, custom headers, JavaScript, and error handling.
- Setting changes: update parser/help text, regenerate CLI/C API docs when possible, then update `docs/settings.md` only for new groups or changed behavior.
- Security-impacting behavior: update `docs/status.md` or `docs/apparmor.md`.
