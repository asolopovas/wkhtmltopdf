---
layout: default
---

# Downloads

Release assets for this fork live in [asolopovas/wkhtmltopdf releases](https://github.com/asolopovas/wkhtmltopdf/releases). Current fork series: **0.13.0**.

## Pick an asset

1. Match OS, distribution release, and CPU architecture.
2. If no exact patch release exists, try the same major/LTS release.
3. If nothing fits, ask in [wkhtmltopdf/packaging](https://github.com/wkhtmltopdf/packaging).

The 0.13.0 Linux `.deb` and Windows installer are built only with wkhtmltopdf patched Qt. Verify an install with `wkhtmltopdf --version`; it must include `(with patched Qt)`. If `wkhtmltopdf --help` reports `Reduced Functionality`, an old unpatched binary is being executed or a bad artifact was installed.

Generic Linux tarballs are no longer shipped because libc, OpenSSL, image libraries, fonts, and fontconfig vary by distribution.

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
- On Linux, `/usr/local/bin` appears before `/usr/bin` on many systems. The `.deb` moves stale `/usr/local/bin/wkhtmltopdf`, `/usr/local/bin/wkhtmltoimage`, and `/usr/local/lib/libwkhtmltox.so*` files aside so the packaged release wins.
