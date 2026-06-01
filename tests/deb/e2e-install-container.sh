#!/usr/bin/env sh
set -eu

expected_version=${EXPECTED_WKHTMLTOX_DEB_VERSION:-1:0.13.0-1.linux}

dpkg -i /tmp/wkhtmltox.deb

installed_version=$(dpkg-query -W -f='${Version}' wkhtmltox)
if [ "$installed_version" != "$expected_version" ]; then
    echo "ERROR: installed version is $installed_version, expected $expected_version" >&2
    exit 1
fi

depends=$(dpkg-deb -f /tmp/wkhtmltox.deb Depends)
case "$depends" in
    *imagemagick*)
        echo "ERROR: ImageMagick must not be a hard dependency" >&2
        exit 1
        ;;
esac

wkhtmltopdf_version=$(wkhtmltopdf --version 2>&1)
wkhtmltoimage_version=$(wkhtmltoimage --version 2>&1)
case "$wkhtmltopdf_version" in
    *"0.13.0 (with patched Qt)"*) ;;
    *) echo "ERROR: unexpected wkhtmltopdf version: $wkhtmltopdf_version" >&2; exit 1 ;;
esac
case "$wkhtmltoimage_version" in
    *"0.13.0 (with patched Qt)"*) ;;
    *) echo "ERROR: unexpected wkhtmltoimage version: $wkhtmltoimage_version" >&2; exit 1 ;;
esac

if [ "$(readlink -f /usr/local/bin/wkhtmltopdf 2>/dev/null || true)" != /usr/bin/wkhtmltopdf ]; then
    echo "ERROR: /usr/local/bin/wkhtmltopdf does not resolve to /usr/bin/wkhtmltopdf" >&2
    exit 1
fi
if [ "$(readlink -f /usr/local/bin/wkhtmltoimage 2>/dev/null || true)" != /usr/bin/wkhtmltoimage ]; then
    echo "ERROR: /usr/local/bin/wkhtmltoimage does not resolve to /usr/bin/wkhtmltoimage" >&2
    exit 1
fi

if ls /usr/local/lib/libwkhtmltox.so* >/dev/null 2>&1; then
    echo "ERROR: stale /usr/local/lib/libwkhtmltox.so* files remain" >&2
    exit 1
fi

wkhtmltopdf --extended-help >/tmp/wkhtmltopdf-help.txt
if grep -Eq 'Reduced Functionality|not using wkhtmltopdf patched Qt' /tmp/wkhtmltopdf-help.txt; then
    echo "ERROR: wkhtmltopdf reports reduced functionality" >&2
    exit 1
fi

printf '%s\n' "deb e2e install passed: $installed_version"
