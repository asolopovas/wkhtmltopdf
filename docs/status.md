---
layout: default
---

# Project status

wkhtmltopdf 0.12.x is mature, useful, and legacy. It depends on Qt WebKit, which receives little upstream maintenance compared with modern browsers.

## Facts

- Official 0.12.x builds use patched Qt 4.8. Qt 4 has been unsupported since 2015; its WebKit is older.
- Qt 5 removed QtWebKit in 2016. Community QtWebKit forks exist, but they lag current WebKit.
- wkhtmltopdf-specific Qt patches were not fully upstreamed, so distribution builds may behave differently from official patched builds.
- Modern Chromium/Puppeteer is usually a better fit for dynamic JavaScript-heavy pages.

## Security

Do **not** render untrusted HTML. A WebKit exploit can become server compromise. If you cannot avoid untrusted input:

- sanitize HTML, CSS, JavaScript, URLs, and local file references;
- disable unnecessary local file and network access;
- run wkhtmltopdf in a sandbox or Mandatory Access Control profile such as [AppArmor](apparmor.html) or SELinux;
- isolate credentials, filesystem paths, caches, logs, and network permissions.

## Recommendations

- For controlled report generation, wkhtmltopdf can still be acceptable.
- For untrusted or highly dynamic content, prefer maintained browser automation such as [Puppeteer].
- For CSS-focused paged media, evaluate [WeasyPrint] or [Prince].
- For security-sensitive deployments, require local sandbox validation before production use.

## Maintenance guidance

- Keep issue reports tied to supported releases and reproducible input.
- Treat generated docs and release artifacts as source-of-truth outputs that must stay fresh.
- Move repeated support answers into docs, tests, or validation scripts instead of relying on maintainer memory.

[Puppeteer]: https://pptr.dev
[WeasyPrint]: https://weasyprint.org
[Prince]: https://www.princexml.com
