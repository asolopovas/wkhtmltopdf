---
layout: default
title: Source guide
---

# Source guide

Maintainer map for source areas not obvious from generated CLI or C API docs.

## Directories

- `src/shared/` — shared CLI parsing, option handlers, help output, progress, console feedback.
- `src/lib/` — conversion library: settings, loading, rendering, output, logging, temp files, C API support.
- `src/pdf/` — `wkhtmltopdf`: PDF options, document objects, outlines, headers, footers, table of contents.
- `src/image/` — `wkhtmltoimage`: image options, viewport, crop, transparency, formats.
- `src/lib/pdf.h`, `src/lib/image.h` — public C API headers installed under `wkhtmltox/`.
- `docs/usage/`, `docs/libwkhtmltox/` — generated CLI and C API docs.
- Packaging — maintained in [wkhtmltopdf/packaging](https://github.com/wkhtmltopdf/packaging).

## Build

Local builds should use all available CPU threads. The convenience target does this by default via `BUILD_JOBS=$(nproc)`:

```sh
make install-dev
make build
```

Manual qmake builds should also pass the available job count:

```sh
mkdir -p build
cd build
qmake ../wkhtmltopdf.pro CONFIG+=silent
make -j"$(nproc)"
```

## Conversion flow

1. CLI parsers or C API calls fill settings structures.
2. `src/lib/multipageloader.*` loads pages and resources using selected network, JavaScript, proxy, cookie, and local-file rules.
3. Qt WebKit renders the `QWebPage`.
4. `PdfConverter` or `ImageConverter` writes output.
5. The shared `Converter` base emits progress, warnings, errors, and success/failure to CLI output or C callbacks.

## PDF path

`wkhtmltopdf` accepts page, cover, and table-of-contents objects. Main files:

- `src/pdf/pdfarguments.cc` — PDF CLI switches.
- `src/pdf/pdfcommandlineparser.*` — object parsing and help output.
- `src/lib/pdfsettings.*` — global and per-object settings.
- `src/lib/pdfconverter.*` — rendering, assembly, outlines, links, headers, footers, output.
- `src/lib/tocstylesheet.*`, `src/lib/doc.cc` — generated TOC stylesheet and doc fragments.

Patched Qt features may be missing or different in distribution builds: multiple inputs, headers/footers, outlines, TOC, smart shrinking controls, and PDF links.

## Image path

`wkhtmltoimage` renders one input to bitmap or SVG. Main files:

- `src/image/imagearguments.cc` — image CLI switches.
- `src/image/imagecommandlineparser.*` — parsing and help output.
- `src/lib/imagesettings.*` — crop, format, quality, viewport, smart width.
- `src/lib/imageconverter.*` — loading, viewport calculation, background, crop, paint, write.

If `fmt` is omitted, output extension selects the format. Qt image writer support controls raster formats; SVG uses `QSvgGenerator`.

## Loading and security

Loading is shared and security-sensitive. Relevant files: `src/lib/loadsettings.*`, `src/lib/reflect.*`, `src/shared/commonarguments.cc`.

Watch authentication, certificates, proxies, cookies, custom headers, JavaScript waits/scripts, local-file access, load-error handling, and print/screen media. If behavior changes risk, filesystem access, or network access, update [Project status](status.html) or [AppArmor](apparmor.html).

## Settings and docs

C API string keys are summarized in [Settings guide](settings.html) and generated in [C API docs](libwkhtmltox/). When CLI options, setting names, or defaults change, update source text, regenerate `docs/usage/` and `docs/libwkhtmltox/` when possible, then update human guides.
