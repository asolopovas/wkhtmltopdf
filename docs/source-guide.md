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
- Packaging — [wkhtmltopdf/packaging](https://github.com/wkhtmltopdf/packaging).

## Workflow

Use the wrapper unless reproducing raw qmake behavior. The default wrapper build uses system Qt; current Linux release packages in this fork also use system Qt 5 so AVIF-capable image plugins can be bundled.

```sh
make           # install/check deps, then configure + build
make test      # smoke test the development build
make install PREFIX="$HOME/.local"
make install PREFIX=/usr/local # uses sudo when /usr/local is not writable
make clean     # keep configuration
make distclean # remove build dir
```

Useful development knobs: `JOBS=8`, `QT=4`, `USE_CCACHE=0`, `AUTO_DEPS=0`, `DESTDIR=/tmp/package`, `PREFIX=/usr`.

Release preview:

```sh
make release DRY_RUN=1
make release VERSION=0.13.0 PUSH=0
make release BUMP=patch
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

System-Qt builds can use distro image plugins such as `qt5-avif-image-plugin`, but they may lack patched-Qt features: multiple inputs, headers/footers, outlines, TOC, smart-shrinking controls, and PDF links. Use the patched-Qt packaging flow only when those features matter more than Qt 5 plugin support.

## Change rules

- Loading changes are security-sensitive: review filesystem, network, credentials, cookies, custom headers, JavaScript, and error handling.
- Setting changes: update parser/help text, regenerate CLI/C API docs when possible, then update `docs/settings.md` only for new groups or changed behavior.
- Security-impacting behavior: update `docs/status.md` or `docs/apparmor.md`.
