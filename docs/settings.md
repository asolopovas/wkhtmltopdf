---
layout: default
title: Settings guide
---

# Settings guide

CLI options and C API keys feed the same C++ settings structures. Generated CLI help and Doxygen are the canonical references.

## Groups

| Group | Source | Surface | Examples |
| --- | --- | --- | --- |
| PDF globals | `src/lib/pdfsettings.*` | global CLI, `wkhtmltopdf_global_settings` | `size.pageSize`, `orientation`, `margin.top`, `outline` |
| PDF objects | `src/lib/pdfsettings.*` | per-page CLI, `wkhtmltopdf_object_settings` | `page`, `header.left`, `footer.right`, `toc.captionText` |
| Image globals | `src/lib/imagesettings.*` | `wkhtmltoimage`, image C API | `screenWidth`, `fmt`, `crop.left`, `transparent` |
| Loading | `src/lib/loadsettings.*` | PDF objects and images | `load.jsdelay`, `load.customHeaders`, `load.proxy` |
| Web rendering | `src/lib/websettings.*` | PDF objects and images | `web.background`, `web.enableJavascript`, `web.userStyleSheet` |

CLI mapping: `src/pdf/pdfarguments.cc`, `src/image/imagearguments.cc`, `src/shared/commonarguments.cc`.

## C API keys

Reflection in `src/lib/reflect.*` exposes dotted keys:

```text
web.enableJavascript
load.jsdelay
margin.top
header.left
crop.width
```

Lists support indexes (`[0]`) and helpers (`first`, `last`, `size`, `clear`, `remove`). Pair values, such as headers and replacements, store name/value strings.

Common value forms: booleans (`true`, `false`), numbers, sizes (`10mm`, `1in`, `72pt`), load handling (`abort`, `skip`, `ignore`), and proxies (`http://host:port`, `socks5://host:port`, optional credentials, or `None`).

## Security-sensitive loading

Loading controls network, local files, scripts, cookies, and request metadata. Review these options carefully:

- local files: `load.blockLocalFileAccess`, `--disable-local-file-access`, `--enable-local-file-access`, `--allow`
- JavaScript: `load.jsdelay`, `load.windowStatus`, `load.runScript`, `--javascript-delay`, `--window-status`, `--run-script`
- requests: `load.customHeaders`, `--custom-header`, `--custom-header-propagation`
- cookies/posts: `load.cookies`, `load.cookieJar`, `load.post`, `--cookie`, `--cookie-jar`, `--post`, `--post-file`
- failures: `load.loadErrorHandling`, `load.mediaLoadErrorHandling`

For risky input, isolate the process and allow-list access. See [Project status](status.html) and [AppArmor](apparmor.html).

## Update rule

When settings change, update parser/help text, regenerate affected CLI/C API docs when possible, and update this guide only for new groups, shared behavior, or changed security expectations.
