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
detect_make_jobs() {
    if [[ -n "${MAKE_JOBS:-}" ]]; then
        printf '%s\n' "${MAKE_JOBS}"
    elif command -v nproc >/dev/null 2>&1; then
        nproc
    elif [[ -n "${NUMBER_OF_PROCESSORS:-}" ]]; then
        printf '%s\n' "${NUMBER_OF_PROCESSORS}"
    elif command -v getconf >/dev/null 2>&1; then
        getconf _NPROCESSORS_ONLN
    else
        printf '2\n'
    fi
}
make_jobs="$(detect_make_jobs)"
echo "using ${make_jobs} parallel build jobs"
package_series="${RELEASE_SERIES:-linux}"
package_arch="${DEB_ARCH:-$(dpkg --print-architecture)}"
multiarch="${DEB_HOST_MULTIARCH:-$(dpkg-architecture -qDEB_HOST_MULTIARCH)}"
package_name="wkhtmltox_${release_version}-${release_iteration}.${package_series}_${package_arch}"
install_base="/opt/wkhtmltox"
libc_version="$(dpkg-query -W -f='${Version}' libc6 | sed 's/-.*//')"

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
"${qmake_bin}" "${REPO_DIR}/wkhtmltopdf.pro" CONFIG+=release CONFIG+=silent INSTALLBASE="${install_base}"
make -j"${make_jobs}"
make install INSTALL_ROOT="${package_root}"

# Install command wrappers in /usr/bin while keeping the real binaries and their
# private runtime in /opt/wkhtmltox. This makes dpkg -i work without requiring
# users to separately install Qt/WebKit/font packages.
mkdir -p "${package_root}/usr/bin" "${package_root}/usr/lib/${multiarch}" "${package_root}/etc/ld.so.conf.d" "${package_root}${install_base}/lib" "${package_root}${install_base}/etc/fonts" "${package_root}${install_base}/share/fonts"
for tool in wkhtmltopdf wkhtmltoimage; do
    mv "${package_root}${install_base}/bin/${tool}" "${package_root}${install_base}/bin/${tool}.bin"
    cat > "${package_root}/usr/bin/${tool}" <<EOF
#!/bin/sh
set -e
export LD_LIBRARY_PATH="${install_base}/lib:\${LD_LIBRARY_PATH:-}"
export FONTCONFIG_FILE="${install_base}/etc/fonts/fonts.conf"
export QT_PLUGIN_PATH="${install_base}/plugins"
if [ -z "\${XDG_RUNTIME_DIR:-}" ]; then
    export XDG_RUNTIME_DIR=/tmp
fi
if [ -z "\${DISPLAY:-}" ] && [ -z "\${QT_QPA_PLATFORM:-}" ]; then
    export QT_QPA_PLATFORM=offscreen
fi
exec "${install_base}/bin/${tool}.bin" "\$@"
EOF
    chmod 0755 "${package_root}/usr/bin/${tool}"
done

if compgen -G "${package_root}${install_base}/lib/libwkhtmltox.so*" >/dev/null; then
    :
elif compgen -G "${package_root}${install_base}/../lib/libwkhtmltox.so*" >/dev/null; then
    mv "${package_root}${install_base}/../lib"/libwkhtmltox.so* "${package_root}${install_base}/lib/"
elif compgen -G "${package_root}/usr/lib/libwkhtmltox.so*" >/dev/null; then
    mv "${package_root}"/usr/lib/libwkhtmltox.so* "${package_root}${install_base}/lib/"
fi

# Bundle Qt plugins needed for headless rendering and common image formats.
qt_plugins_dir="$(${qmake_bin} -query QT_INSTALL_PLUGINS)"
if [[ -d "${qt_plugins_dir}" ]]; then
    mkdir -p "${package_root}${install_base}/plugins"
    for plugin_group in platforms imageformats iconengines printsupport bearer; do
        if [[ -d "${qt_plugins_dir}/${plugin_group}" ]]; then
            cp -a "${qt_plugins_dir}/${plugin_group}" "${package_root}${install_base}/plugins/"
        fi
    done
fi

# Qt 5 loads OpenSSL at runtime, so ldd will not report these dependencies.
for crypto_lib in /usr/lib/${multiarch}/libssl.so.* /usr/lib/${multiarch}/libcrypto.so.*; do
    if [[ -f "${crypto_lib}" ]]; then
        cp -L "${crypto_lib}" "${package_root}${install_base}/lib/"
    fi
done

# Bundle dynamically linked runtime libraries from the build distribution, but
# leave glibc/the dynamic loader to the host for Debian/Ubuntu/Mint amd64
# compatibility. The package metadata records the build base's libc floor.
skip_regex='/(ld-linux-x86-64|libBrokenLocale|libSegFault|libanl|libc|libdl|libm|libmemusage|libmvec|libnsl|libnss_.*|libpthread|libresolv|librt|libthread_db|libutil)\.so(\.|$)'
copy_runtime_deps() {
    local copied_any=true
    while [[ "${copied_any}" == true ]]; do
        copied_any=false
        while IFS= read -r dep; do
            [[ -f "${dep}" ]] || continue
            if [[ "${dep}" =~ ${skip_regex} ]]; then
                continue
            fi
            local target="${package_root}${install_base}/lib/$(basename "${dep}")"
            if [[ ! -e "${target}" ]]; then
                cp -L "${dep}" "${target}"
                copied_any=true
            fi
        done < <(
            find "${package_root}${install_base}/bin" "${package_root}${install_base}/lib" "${package_root}${install_base}/plugins" -type f \( -perm -0100 -o -name '*.so*' \) -print0 |
                xargs -0 -r ldd 2>/dev/null |
                awk '/=> \/.* \(/ { print $3 } /^\// { print $1 }' |
                sort -u
        )
    done
}
copy_runtime_deps

# Copy a small baseline font set and point wrappers at it.
for font_dir in /usr/share/fonts/truetype/dejavu /usr/share/fonts/dejavu; do
    if [[ -d "${font_dir}" ]]; then
        cp -a "${font_dir}" "${package_root}${install_base}/share/fonts/"
    fi
done
cat > "${package_root}${install_base}/etc/fonts/fonts.conf" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir>${install_base}/share/fonts</dir>
  <cachedir>/var/cache/fontconfig</cachedir>
  <config></config>
</fontconfig>
EOF

echo "${install_base}/lib" > "${package_root}/etc/ld.so.conf.d/wkhtmltox.conf"
for lib in "${package_root}${install_base}/lib"/libwkhtmltox.so*; do
    [[ -e "${lib}" ]] || continue
    ln -s "${install_base}/lib/$(basename "${lib}")" "${package_root}/usr/lib/${multiarch}/$(basename "${lib}")"
done

mkdir -p "${package_root}/DEBIAN"
cat > "${package_root}/DEBIAN/control" <<EOF
Package: wkhtmltox
Version: ${release_version}-${release_iteration}.${package_series}
Section: utils
Priority: optional
Architecture: ${package_arch}
Maintainer: wkhtmltopdf maintainers <support@wkhtmltopdf.org>
Depends: libc6 (>= ${libc_version})
Conflicts: wkhtmltopdf
Replaces: wkhtmltopdf
Provides: wkhtmltopdf
Homepage: https://wkhtmltopdf.org/
Description: convert HTML to PDF and images using bundled Qt WebKit
 wkhtmltox contains wkhtmltopdf and wkhtmltoimage command line tools plus
 libwkhtmltox. Runtime Qt/WebKit libraries and baseline fonts are bundled so
 the package can be installed directly with dpkg on amd64 Debian, Ubuntu, and
 Linux Mint systems with a compatible glibc.
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
