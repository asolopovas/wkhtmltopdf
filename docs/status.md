---
layout: default
---

# Project status

wkhtmltopdf 0.12.x is useful but legacy. It depends on Qt WebKit.

## Facts

- Official builds use patched Qt 4.8. Qt 4 has been unsupported since 2015.
- Qt 5 removed QtWebKit in 2016; community forks lag current WebKit.
- wkhtmltopdf Qt patches were not fully upstreamed, so distribution builds may differ.
- Chromium/Puppeteer is usually better for dynamic JavaScript-heavy pages.

## Security

Do **not** render untrusted HTML without isolation. A WebKit exploit can become server compromise. For risky input, sanitize content and restrict filesystem, network, credentials, caches, logs, and process privileges with a sandbox, [AppArmor](apparmor.html), or SELinux.

## Use guidance

- Controlled report generation: wkhtmltopdf can be acceptable.
- Untrusted or highly dynamic content: prefer [Puppeteer].
- CSS-focused paged media: evaluate [WeasyPrint] or [Prince].
- Security-sensitive deployments: require local sandbox validation.

## Maintenance

Tie reports to supported releases and reproducible input. Keep generated docs and release artifacts fresh. Move repeated support answers into docs, tests, scripts, or checks.

[Puppeteer]: https://pptr.dev
[WeasyPrint]: https://weasyprint.org
[Prince]: https://www.princexml.com
