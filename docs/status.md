---
layout: default
---

# Project status

wkhtmltopdf 0.12.x is useful but legacy. It depends on Qt WebKit.

## Facts

- Official builds use patched Qt 4.8. Qt 4 has been unsupported since 2015.
- Qt 5 removed QtWebKit in 2016; community forks lag current WebKit.
- wkhtmltopdf Qt patches were not fully upstreamed, so distribution builds may differ.
- AVIF images can be loaded by QtWebKit through Qt image plugins such as `qt5-avif-image-plugin`; wkhtmltopdf allows the `avif` Qt image format by default when such a plugin is installed.
- Chromium/Puppeteer is usually better for dynamic JavaScript-heavy pages and for modern browser features that QtWebKit does not implement, especially CSS grid.

## Security

Do **not** render untrusted HTML without isolation. A WebKit exploit can become server compromise. For risky input, sanitize content and restrict filesystem, network, credentials, caches, logs, and process privileges with a sandbox, [AppArmor](apparmor.html), or SELinux.

## Use guidance

- Controlled report generation: wkhtmltopdf can be acceptable and remains the fastest path.
- AVIF-heavy pages: install a Qt AVIF image plugin and keep using wkhtmltopdf.
- Controlled templates that use CSS grid: provide flex/table/block fallbacks before grid declarations so QtWebKit stays on the fast path.
- Untrusted, highly dynamic, or JavaScript-heavy modern content: prefer [Puppeteer] or Chromium.
- CSS-focused paged media: evaluate [WeasyPrint] or [Prince].
- Security-sensitive deployments: require local sandbox validation.

## Technical debt

- The rendering engine is still legacy QtWebKit; adding full CSS grid support means browser-engine work, not a small wkhtmltopdf patch.
- AVIF support depends on an external Qt image plugin and codec stack. Packaging must include and test that plugin, otherwise AVIF falls back to broken-image placeholders.
- QtWebKit blocks non-built-in image formats unless whitelisted. wkhtmltopdf now defaults `QTWEBKIT_IMAGEFORMAT_WHITELIST` to `avif` when the variable is unset so installed AVIF plugins work; deployments that set a custom whitelist must include `avif` themselves. Treat image decoders as part of the trusted rendering surface.
- Template owners should maintain print-oriented fallbacks for grid layouts. Prefer table/flex/block fallbacks first, then wrap grid enhancements in `@supports (display: grid)` for browsers.

## Maintenance

Tie reports to supported releases and reproducible input. Keep generated docs and release artifacts fresh. Move repeated support answers into docs, tests, scripts, or checks.

[Puppeteer]: https://pptr.dev
[WeasyPrint]: https://weasyprint.org
[Prince]: https://www.princexml.com
