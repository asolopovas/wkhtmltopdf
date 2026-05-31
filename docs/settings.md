---
layout: default
title: Settings guide
---

# Settings guide

wkhtmltopdf has two public settings surfaces: generated CLI help and generated C API Doxygen. Both feed the same C++ settings structures.

## Groups

| Group | Source | Surface | Examples |
| --- | --- | --- | --- |
| PDF globals | `src/lib/pdfsettings.*` | global CLI, `wkhtmltopdf_global_settings` | `size.pageSize`, `orientation`, `margin.top`, `outline` |
| PDF objects | `src/lib/pdfsettings.*` | per-page CLI, `wkhtmltopdf_object_settings` | `page`, `header.left`, `footer.right`, `toc.captionText` |
| Image globals | `src/lib/imagesettings.*` | `wkhtmltoimage`, image C API | `screenWidth`, `fmt`, `crop.left`, `transparent` |
| Loading | `src/lib/loadsettings.*` | PDF objects and images | `load.jsdelay`, `load.customHeaders`, `load.proxy` |
| Web rendering | `src/lib/websettings.*` | PDF objects and images | `web.background`, `web.enableJavascript`, `web.userStyleSheet` |

CLI mapping lives in `src/pdf/pdfarguments.cc`, `src/image/imagearguments.cc`, and `src/shared/commonarguments.cc`.

## C API keys

Reflection in `src/lib/reflect.*` exposes dotted keys:

```text
web.enableJavascript
load.jsdelay
margin.top
header.left
crop.width
```

Lists accept indexed access such as `[0]`, plus helper names such as `first`, `last`, `size`, `clear`, and `remove`. Pair values, including custom headers and replacements, store name/value strings.

Common value forms:

- booleans: `true`, `false`
- numbers: decimal strings
- sizes: `10mm`, `1in`, `72pt`
- load handling: `abort`, `skip`, `ignore`
- proxy: `http://host:port`, `socks5://host:port`, optional credentials, or `None`

## Security-sensitive loading

Loading controls network requests, local files, scripts, cookies, and request metadata. Key options include:

- local files: `load.blockLocalFileAccess`, `--disable-local-file-access`, `--enable-local-file-access`, `--allow`
- JavaScript: `load.jsdelay`, `load.windowStatus`, `load.runScript`, `--javascript-delay`, `--window-status`, `--run-script`
- requests: `load.customHeaders`, `--custom-header`, `--custom-header-propagation`
- cookies/posts: `load.cookies`, `load.cookieJar`, `load.post`, `--cookie`, `--cookie-jar`, `--post`, `--post-file`
- failures: `load.loadErrorHandling`, `load.mediaLoadErrorHandling`

For risky input, isolate the process and allow-list access. See [Project status](status.html) and [AppArmor](apparmor.html).

## PDF settings

PDF has global and per-object levels. Globals cover page size, orientation, margins, output, copies, outline, and image compression. Objects cover input pages, headers/footers, links, forms, TOC behavior, and loading. Header/footer replacements provide page and web-page values; custom replacements extend them. TOC output comes from the outline tree and XSLT (`--dump-default-toc-xsl`, `--xsl-style-sheet`).

## Image settings

Image output has one input and output. Important fields: viewport (`screenWidth`, `screenHeight`), `smartWidth`, crop rectangle, `fmt`, and `transparent` for PNG/SVG backgrounds.

## Update checklist

When a setting changes, update nearby source comments/parser text, regenerate affected CLI and C API docs, and update this guide only for new groups, shared behavior, or changed security expectations.
