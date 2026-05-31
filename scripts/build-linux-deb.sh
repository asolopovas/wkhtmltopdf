#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"

release_version="${RELEASE_VERSION:-$(tr -d '[:space:]' < "${REPO_DIR}/VERSION")}"
release_version="${release_version//[[:space:]]/}"
release_iteration="${RELEASE_ITERATION:-1}"
release_output="${RELEASE_OUTPUT:-${REPO_DIR}/releases/${release_version}}"
case "${release_output}" in
    /*) ;;
    *) release_output="${REPO_DIR}/${release_output}" ;;
esac
qmake_bin="${QMAKE:-qmake}"
make_jobs="${MAKE_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '2')}"
ubuntu_series="${RELEASE_SERIES:-noble}"
package_arch="${DEB_ARCH:-$(dpkg --print-architecture)}"
multiarch="${DEB_HOST_MULTIARCH:-$(dpkg-architecture -qDEB_HOST_MULTIARCH)}"
package_name="wkhtmltox_${release_version}-${release_iteration}.${ubuntu_series}_${package_arch}"

case "${release_version}" in
    *[!0-9A-Za-z.+:~_-]*|'')
        echo "invalid RELEASE_VERSION: ${release_version}" >&2
        exit 2
        ;;
esac

build_dir="$(mktemp -d "${TMPDIR:-/tmp}/wkhtmltox-build.XXXXXX")"
package_root="$(mktemp -d "${TMPDIR:-/tmp}/wkhtmltox-package.XXXXXX")"
cleanup() {
    rm -rf "${build_dir}" "${package_root}"
}
trap cleanup EXIT

mkdir -p "${release_output}/linux-deb"
rm -f "${release_output}/linux-deb"/*.deb

export WKHTMLTOX_VERSION="${release_version}"
cd "${build_dir}"
"${qmake_bin}" "${REPO_DIR}/wkhtmltopdf.pro" CONFIG+=release CONFIG+=silent INSTALLBASE=/usr
make -j"${make_jobs}"
make install INSTALL_ROOT="${package_root}"

mkdir -p "${package_root}/usr/lib/${multiarch}"
if compgen -G "${package_root}/usr/lib/libwkhtmltox.so*" >/dev/null; then
    mv "${package_root}"/usr/lib/libwkhtmltox.so* "${package_root}/usr/lib/${multiarch}/"
fi

mkdir -p "${package_root}/DEBIAN"
cat > "${package_root}/DEBIAN/control" <<EOF
Package: wkhtmltox
Version: ${release_version}-${release_iteration}.${ubuntu_series}
Section: utils
Priority: optional
Architecture: ${package_arch}
Maintainer: wkhtmltopdf maintainers <support@wkhtmltopdf.org>
Depends: ca-certificates, fontconfig, libc6, libgcc-s1, libstdc++6, libqt5core5t64, libqt5gui5t64, libqt5network5t64, libqt5printsupport5t64, libqt5svg5, libqt5webkit5, libqt5widgets5t64, libqt5xmlpatterns5, xfonts-75dpi, xfonts-base, zlib1g
Conflicts: wkhtmltopdf
Replaces: wkhtmltopdf
Provides: wkhtmltopdf
Homepage: https://wkhtmltopdf.org/
Description: convert HTML to PDF and images using Qt WebKit
 wkhtmltox contains wkhtmltopdf and wkhtmltoimage command line tools plus
 libwkhtmltox. This package is built with the stable Ubuntu ${ubuntu_series}
 Qt 5 packages available on the GitHub Actions runner.
EOF

cat > "${package_root}/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if command -v ldconfig >/dev/null 2>&1; then
    ldconfig
fi
EOF
chmod 0755 "${package_root}/DEBIAN/postinst"

cat > "${package_root}/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
if command -v ldconfig >/dev/null 2>&1; then
    ldconfig
fi
EOF
chmod 0755 "${package_root}/DEBIAN/postrm"

find "${package_root}" -type d -exec chmod 0755 {} +
dpkg-deb --root-owner-group --build "${package_root}" "${release_output}/linux-deb/${package_name}.deb"
(
    cd "${release_output}"
    find linux-deb -maxdepth 1 -type f -name '*.deb' -print | sort | xargs sha256sum > checksums-linux-deb.txt
)
