---
layout: default
title: Settings guide
---

# Settings guide

wkhtmltopdf has two public settings surfaces:

- command-line switches, documented in generated usage files;
- C API string keys, documented in generated Doxygen under `docs/libwkhtmltox/`.

Both surfaces feed the same C++ settings structures. This guide summarizes the
shared model so users can connect a CLI option, a C API key, and the code that
implements it.

## Setting groups

| Group | Main source | Used by | Examples |
| --- | --- | --- | --- |
| PDF globals | `src/lib/pdfsettings.*` | `wkhtmltopdf_global_settings` and global CLI options | `size.pageSize`, `orientation`, `margin.top`, `outline`, `documentTitle` |
| PDF objects | `src/lib/pdfsettings.*` | `wkhtmltopdf_object_settings` and per-page CLI options | `page`, `header.left`, `footer.right`, `toc.captionText`, `produceForms` |
| Image globals | `src/lib/imagesettings.*` | image C API settings and `wkhtmltoimage` CLI options | `screenWidth`, `screenHeight`, `fmt`, `crop.left`, `transparent` |
| Loading | `src/lib/loadsettings.*` | PDF objects and images | `load.jsdelay`, `load.windowStatus`, `load.customHeaders`, `load.proxy`, `load.loadErrorHandling` |
| Web rendering | `src/lib/websettings.*` | PDF objects and images | `web.background`, `web.enableJavascript`, `web.defaultEncoding`, `web.userStyleSheet` |

The command-line parser maps human-friendly switches to these fields in:

- `src/pdf/pdfarguments.cc` for `wkhtmltopdf`;
- `src/image/imagearguments.cc` for `wkhtmltoimage`;
- `src/shared/commonarguments.cc` for options shared by both.

## C API string keys

The C API uses reflection from `src/lib/reflect.*`. Nested fields are separated
with dots:

```text
web.enableJavascript
load.jsdelay
margin.top
header.left
crop.width
```

Lists use indexes or helper names. Internally, list reflection accepts indexed
access such as `[0]`, plus `first`, `last`, `size`, `clear`, and `remove`
operations. Pair-like values such as custom headers and replacements are stored
as name/value pairs.

Because the C API accepts strings, values are parsed by type:

- booleans: `true` or `false`;
- integers and floats: decimal strings;
- sizes and margins: unit strings such as `10mm`, `1in`, or `72pt`;
- load handling: `abort`, `skip`, or `ignore`;
- proxy: `http://host:port`, `socks5://host:port`, optional credentials, or
  `None` to bypass proxy use.

## Loading and security-sensitive settings

Loading options affect network requests, local file access, script execution,
and cookies. Treat them as security-sensitive when rendering input you do not
fully control.

Important settings and switches include:

- local file access: `load.blockLocalFileAccess`, `--disable-local-file-access`,
  `--enable-local-file-access`, and repeatable `--allow`;
- JavaScript timing: `load.jsdelay`, `load.windowStatus`, `--javascript-delay`,
  and `--window-status`;
- script injection: repeatable `load.runScript` / `--run-script`;
- request metadata: `load.customHeaders`, `--custom-header`, and
  `--custom-header-propagation`;
- cookies and posts: `load.cookies`, `load.cookieJar`, `load.post`,
  `--cookie`, `--cookie-jar`, `--post`, and `--post-file`;
- failures: `load.loadErrorHandling` and `load.mediaLoadErrorHandling`.

For risky input, prefer isolation and an allow-list rather than trying to make a
single option safe. See [Project status](status.html) and
[AppArmor](apparmor.html).

## PDF-specific areas

PDF output has a global level and a per-object level. Global settings cover page
size, orientation, margins, output file, copies, outline generation, and image
compression. Per-object settings cover the input page, headers and footers,
links, forms, table-of-contents behavior, and object-specific loading.

Header and footer text can use substitutions such as page number and webpage
values. The `replacements` list adds custom substitution values.

Table-of-contents output is built from the outline tree. The default stylesheet
can be dumped by `--dump-default-toc-xsl` and customized with
`--xsl-style-sheet`.

## Image-specific areas

Image output uses a single input and a single output. Important image settings
are:

- `screenWidth` and `screenHeight`, which define the WebKit viewport;
- `smartWidth`, which can expand the width to fit unbreakable content;
- `crop.left`, `crop.top`, `crop.width`, and `crop.height`;
- `fmt`, inferred from the output extension if omitted;
- `transparent`, which affects PNG and SVG backgrounds.

## Documentation update checklist

When adding or changing a setting:

1. Update the source-level comment near the field or parser entry.
2. Update the generated CLI usage if a command-line switch changed.
3. Update generated C API docs if a public setting changed.
4. Update this guide when the setting belongs to a new group, changes security
   expectations, or is shared between `wkhtmltopdf` and `wkhtmltoimage`.
