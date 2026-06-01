---
layout: default
---

# Downloads

Release assets live in [wkhtmltopdf/packaging releases](https://github.com/wkhtmltopdf/packaging/releases). Current stable series: **0.12.6**; some Linux assets are **0.12.6.1** rebuilds.

## Pick an asset

1. Match OS, distribution release, and CPU architecture.
2. If no exact patch release exists, try the same major/LTS release.
3. If nothing fits, ask in [wkhtmltopdf/packaging](https://github.com/wkhtmltopdf/packaging).

Legacy official packages use patched Qt. This fork's AVIF-capable Linux packages use system Qt 5 with bundled Qt image plugins, so they may differ from patched-Qt builds. Generic Linux binaries are no longer shipped because libc, OpenSSL, image libraries, fonts, and fontconfig vary by distribution.

## Archive

Older assets: [wkhtmltopdf releases](https://github.com/wkhtmltopdf/wkhtmltopdf/releases), [packaging releases](https://github.com/wkhtmltopdf/packaging/releases), [obsolete downloads](https://github.com/wkhtmltopdf/obsolete-downloads/blob/master/README.md). Report bugs against the latest stable release unless reporting a regression.

## AWS Lambda

Use the Amazon Linux 2 Lambda zip. Unzip into `layer/`, then test:

```bash
docker run --rm -v "$PWD/layer:/opt" amazonlinux:2 \
  /bin/bash -lc 'LD_LIBRARY_PATH=/opt/lib FONTCONFIG_PATH=/opt/fonts /opt/bin/wkhtmltopdf https://google.com/ /opt/google.pdf'
```

Set `FONTCONFIG_PATH=/opt/fonts` in Lambda.

## Notes

- Read [Project status](status.html) and [AppArmor](apparmor.html) before processing risky HTML.
- Symantec `WS.Reputation.1` is reputation-based; verify Windows downloads against GitHub release assets.
