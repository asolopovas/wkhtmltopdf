---
layout: default
---

# Downloads

All release assets are hosted in [GitHub releases](https://github.com/wkhtmltopdf/packaging/releases).

Current stable series: **0.12.6**. Some Linux packages use the rebuild version **0.12.6.1**.

## Get a build

1. Open the [packaging releases](https://github.com/wkhtmltopdf/packaging/releases).
2. Choose the newest asset matching your OS, distribution, release, and CPU architecture.
3. If your exact patch release is missing, try the same distribution major/LTS release.
4. If your platform is missing, discuss it in the [packaging repository](https://github.com/wkhtmltopdf/packaging).

Do **not** render untrusted HTML. See the [project status](status.html) and [AppArmor example](apparmor.html).

## Build notes

Official packages are built by the separate [packaging project](https://github.com/wkhtmltopdf/packaging). Distribution packages may use unpatched Qt and can behave differently from official patched builds.

Generic Linux binaries are no longer provided. Native packages are safer because libc, OpenSSL, image libraries, fonts, and fontconfig vary by distribution.

## Archive

Older releases are available from the [wkhtmltopdf releases](https://github.com/wkhtmltopdf/wkhtmltopdf/releases), [packaging releases](https://github.com/wkhtmltopdf/packaging/releases), and [obsolete downloads](https://github.com/wkhtmltopdf/obsolete-downloads/blob/master/README.md). Bug reports should target the latest stable release unless you are reporting a regression.

## AWS Lambda

Use the Amazon Linux 2 Lambda zip from the packaging releases. Unzip it into `layer/`, then test locally:

```bash
docker run --rm -v "$PWD/layer:/opt" amazonlinux:2 \
  /bin/bash -lc 'LD_LIBRARY_PATH=/opt/lib FONTCONFIG_PATH=/opt/fonts /opt/bin/wkhtmltopdf https://google.com/ /opt/google.pdf'
```

Set `FONTCONFIG_PATH=/opt/fonts` in the Lambda function or layer.

## Windows antivirus warning

Symantec `WS.Reputation.1` is a reputation-based false positive for rarely seen files. Verify downloads against GitHub release assets.
