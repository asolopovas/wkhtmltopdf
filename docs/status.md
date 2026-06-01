---
layout: default
---

# Project status

wkhtmltopdf 0.12.x is useful but legacy. It depends on Qt WebKit.

## Facts

- Legacy official builds use patched Qt 4.8; Qt 4 has been unsupported since 2015.
- Qt 5 removed QtWebKit in 2016; community forks lag current WebKit.
- System-Qt builds may miss wkhtmltopdf Qt patches, but they can use distro image plugins such as AVIF.
- AVIF works only when a Qt image plugin, such as `qt5-avif-image-plugin`, is installed/bundled and allowed by `QTWEBKIT_IMAGEFORMAT_WHITELIST`.
- CSS grid, modern browser APIs, and JavaScript-heavy pages are better served by Chromium/Puppeteer.

## Security

Do **not** render untrusted HTML without isolation. Treat WebKit, image decoders, fonts, network access, local files, credentials, caches, and logs as attack surface. Use sanitization plus a sandbox such as [AppArmor](apparmor.html) or SELinux.

## Choose a renderer

- Controlled reports: wkhtmltopdf is acceptable and fast.
- AVIF-heavy controlled pages: install and package-test a Qt AVIF plugin.
- Templates using modern CSS: provide table/flex/block fallbacks before grid rules.
- Untrusted or dynamic modern pages: prefer [Puppeteer] or Chromium.
- CSS paged media: evaluate [WeasyPrint] or [Prince].

## Maintenance

Keep reports reproducible. Move repeated support answers into docs, tests, scripts, generated output, or checks.

[Puppeteer]: https://pptr.dev
[WeasyPrint]: https://weasyprint.org
[Prince]: https://www.princexml.com
