---
layout: default
title: Source guide
---

# Source guide

This page gives maintainers and contributors a map of the source tree. It is
not a replacement for the generated command-line help or C API reference; it
fills in the areas that are easiest to miss when reading those generated docs.

## Main directories

- `src/shared/` — shared command-line parsing, argument handlers, generated
  help output, progress reporting, and console feedback.
- `src/lib/` — the conversion library used by both CLIs and the C API. This is
  where settings, loading, conversion, PDF assembly, image output, logging, and
  temporary file handling live.
- `src/pdf/` — the `wkhtmltopdf` executable, PDF-specific command-line options,
  document object handling, outlines, headers, footers, and table-of-contents
  integration.
- `src/image/` — the `wkhtmltoimage` executable, image-specific command-line
  options, viewport sizing, cropping, transparency, and image format handling.
- `include/wkhtmltox/` via `src/lib/*.h` — public C API headers for embedding
  the library.
- `docs/libwkhtmltox/` — generated Doxygen documentation for the C API and
  reflected settings.
- `docs/usage/` — generated command-line help. Regenerate these from the
  matching binaries when CLI behavior changes.
- `packaging/` — official packaging is maintained in the separate
  [`wkhtmltopdf/packaging`](https://github.com/wkhtmltopdf/packaging)
  repository.

## Conversion flow

At a high level, both tools follow the same path:

1. Command-line handlers in `src/shared/` and the tool-specific parser fill a
   settings structure.
2. The C API can fill the same structures by string keys such as
   `web.enableJavascript` or `load.jsdelay`.
3. `src/lib/multipageloader.*` loads the main page and its resources with the
   selected network, JavaScript, proxy, cookie, and local-file rules.
4. The converter renders the loaded `QWebPage` through Qt WebKit.
5. PDF output flows through `PdfConverter`; image output flows through
   `ImageConverter`.
6. Progress, warnings, errors, and final success/failure are emitted through the
   shared `Converter` base class and surfaced by the CLI or C callbacks.

## PDF path

`wkhtmltopdf` accepts one or more document objects:

- page objects for normal HTML input;
- cover objects, which do not appear in the table of contents and do not use
  headers or footers;
- table-of-contents objects, generated from the PDF outline XML and styled with
  XSLT.

The main code areas are:

- `src/pdf/pdfarguments.cc` — PDF CLI switches and their settings mapping.
- `src/pdf/pdfcommandlineparser.*` — object parsing and CLI documentation
  output.
- `src/lib/pdfsettings.*` — global and per-object PDF settings.
- `src/lib/pdfconverter.*` — page rendering, PDF assembly, outlines, links,
  headers, footers, and output handling.
- `src/lib/tocstylesheet.*` and `src/lib/doc.cc` — generated table-of-contents
  stylesheet and static documentation fragments.

Some PDF features depend on the patched Qt used by official builds. Distribution
builds that use unpatched Qt may not support multiple input documents, headers
and footers, outlines, table of contents, smart shrinking controls, or PDF link
features in the same way.

## Image path

`wkhtmltoimage` renders a single input to a bitmap or SVG output.

The main code areas are:

- `src/image/imagearguments.cc` — image CLI switches and their settings mapping.
- `src/image/imagecommandlineparser.*` — image CLI parsing and documentation
  output.
- `src/lib/imagesettings.*` — image settings, including crop rectangle, output
  format, quality, viewport width/height, and smart-width behavior.
- `src/lib/imageconverter.*` — page loading, viewport calculation, transparent
  background handling, cropping, painting, and output writing.

If the image format is not set explicitly, it is inferred from the output file
extension. Standard Qt image writer support controls the available raster
formats; SVG output uses `QSvgGenerator`.

## Shared loading and rendering behavior

The loader is security-sensitive and is shared by PDF and image conversion.
Important settings are defined in `src/lib/loadsettings.*`, reflected through
`src/lib/reflect.*`, and wired to CLI options in `src/shared/commonarguments.cc`.
They include:

- authentication, client certificate, proxy, and proxy bypass settings;
- cookie jar and per-request cookies;
- custom headers and whether headers are propagated to subresources;
- JavaScript delay, `window.status` waits, and injected scripts;
- local file access controls and explicit allow-list paths;
- load-error handling for main pages and media resources;
- print-media versus screen-media selection.

When changing loader behavior, update security guidance in `docs/status.md` or
`docs/apparmor.md` if the change affects risky input, filesystem access, or
network access.

## Settings and C API

The C API exposes settings through string keys. The reflected settings model is
documented in more detail in [Settings guide](settings.html) and the generated
[C API documentation](libwkhtmltox/).

## Documentation maintenance

When changing CLI options, settings names, or defaults:

1. Update the source comments or option text close to the code.
2. Regenerate the relevant generated help in `docs/usage/` and C API docs in
   `docs/libwkhtmltox/` when possible.
3. Update human-written overview pages such as this guide when behavior spans
   more than one source area.
