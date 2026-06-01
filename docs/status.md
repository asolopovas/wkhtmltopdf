---
layout: default
---

# Project status

wkhtmltopdf 0.12.x is useful but legacy. It depends on Qt WebKit.

## Facts

- Release builds in this fork use wkhtmltopdf patched Qt 4.8 for full PDF functionality.
- Qt 4 has been unsupported since 2015, and Qt WebKit remains legacy technology.
- System-Qt development builds are rejected for release packaging because they miss wkhtmltopdf Qt patches.
- AVIF images are decoded through an external ImageMagick-compatible converter in the patched-Qt release lane.
- CSS grid, modern browser APIs, and JavaScript-heavy pages are better served by Chromium/Puppeteer.

## Security

Do **not** render untrusted HTML without isolation. Treat WebKit, image decoders, fonts, network access, local files, credentials, caches, and logs as attack surface. Use sanitization plus a sandbox such as [AppArmor](apparmor.html) or SELinux.

## Choose a renderer

- Controlled reports: wkhtmltopdf is acceptable and fast.
- AVIF-heavy controlled pages: wkhtmltopdf can render static AVIF through ImageMagick, but Chromium/Puppeteer remains faster for modern media-heavy pages.
- Templates using modern CSS: provide table/flex/block fallbacks before grid rules.
- Untrusted or dynamic modern pages: prefer [Puppeteer] or Chromium.
- CSS paged media: evaluate [WeasyPrint] or [Prince].

## Maintenance

Keep reports reproducible. Move repeated support answers into docs, tests, scripts, generated output, or checks.

[Puppeteer]: https://pptr.dev
[WeasyPrint]: https://weasyprint.org
[Prince]: https://www.princexml.com
