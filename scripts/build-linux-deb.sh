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
log_root="${WKHTMLTOX_LOG_DIR:-${REPO_DIR}/tmp/logs}"
mkdir -p "${log_root}"
log_file="${log_root}/build-linux-deb-$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
touch "${log_file}"
echo "build-linux-deb: logging to ${log_file}"
exec > >(tee -a "${log_file}") 2>&1
echo "build-linux-deb: logging to ${log_file}"

# A previously installed broken wkhtmltox package may have put /opt/wkhtmltox/lib
# into the host ld.so cache. Force Debian tooling to prefer system libraries so
# package builds/tests still run long enough to replace the bad package.
system_ld_library_path="/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:/lib:/usr/lib"
system_tool_env=(env LD_LIBRARY_PATH="${system_ld_library_path}")

die() {
    echo "ERROR: $*" >&2
    exit 1
}

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
package_arch="${DEB_ARCH:-$("${system_tool_env[@]}" dpkg --print-architecture)}"
multiarch="${DEB_HOST_MULTIARCH:-$("${system_tool_env[@]}" dpkg-architecture -qDEB_HOST_MULTIARCH)}"
package_name="wkhtmltox_${release_version}-${release_iteration}.${package_series}_${package_arch}"
install_base="/opt/wkhtmltox"
libc_version="$("${system_tool_env[@]}" dpkg-query -W -f="\${Version}" libc6 | sed 's/-.*//')"

case "${release_version}" in
    *[!0-9A-Za-z.+:~_-]*|'')
        echo "invalid RELEASE_VERSION: ${release_version}" >&2
        exit 2
        ;;
esac

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

qt_header_has_patch_marker() {
    local header include target
    header="$1"
    [[ -f "${header}" ]] || return 1
    if grep -q '__EXTENSIVE_WKHTMLTOPDF_QT_HACK__' "${header}"; then
        return 0
    fi
    include="$(sed -n 's/^#include "\(.*\)"/\1/p' "${header}" | head -n 1)"
    if [[ -n "${include}" ]]; then
        target="${include}"
        if [[ "${target}" != /* ]]; then
            target="$(dirname "${header}")/${target}"
        fi
        [[ -f "${target}" ]] && grep -q '__EXTENSIVE_WKHTMLTOPDF_QT_HACK__' "${target}"
        return $?
    fi
    return 1
}

require_patched_qt() {
    require_command "${qmake_bin}"
    local qt_headers qt_version header found=false
    qt_headers="$(${qmake_bin} -query QT_INSTALL_HEADERS 2>/dev/null || true)"
    qt_version="$(${qmake_bin} -query QT_VERSION 2>/dev/null || true)"
    for header in \
        "${qt_headers}/QtWebKit/qwebframe.h" \
        "${qt_headers}/qwebframe.h"; do
        if qt_header_has_patch_marker "${header}"; then
            found=true
            break
        fi
    done
    if [[ "${found}" != true ]]; then
        cat >&2 <<EOF
ERROR: ${qmake_bin} points to Qt ${qt_version:-unknown} without the wkhtmltopdf Qt patches.
Release packages must be full-functionality builds; refusing to create a reduced-functionality .deb.
Use QMAKE=/path/to/patched-qt/bin/qmake from the wkhtmltopdf patched Qt 4.8 tree.
EOF
        exit 2
    fi
}

require_patched_qt
require_command patchelf
require_command readelf
require_command strings
require_command file

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
mkdir -p "${package_root}/usr/bin" "${package_root}/usr/lib/${multiarch}" "${package_root}${install_base}/lib" "${package_root}${install_base}/etc/fonts" "${package_root}${install_base}/share/fonts"
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

# Qt loads OpenSSL at runtime on some builds, so ldd may not report these dependencies.
for crypto_lib in "/usr/lib/${multiarch}"/libssl.so.* "/usr/lib/${multiarch}"/libcrypto.so.*; do
    if [[ -f "${crypto_lib}" ]]; then
        cp -L "${crypto_lib}" "${package_root}${install_base}/lib/"
    fi
done

# Bundle dynamically linked runtime libraries from the build distribution, but
# leave glibc/the dynamic loader to the host for Debian/Ubuntu/Mint amd64
# compatibility. The package metadata records the build base's libc floor.
skip_regex='/(ld-linux-x86-64|libBrokenLocale|libSegFault|libanl|libc|libdl|libm|libmemusage|libmvec|libnsl|libnss_.*|libpthread|libresolv|librt|libthread_db|libutil)\.so(\.|$)'

copy_toolchain_runtime_deps() {
    local query dep target
    for query in \
        "${CXX:-g++} -print-file-name=libstdc++.so.6" \
        "${CC:-gcc} -print-libgcc-file-name"; do
        dep="$(${query} 2>/dev/null || true)"
        [[ -f "${dep}" ]] || continue
        [[ "${dep}" =~ ${skip_regex} ]] && continue
        target="${package_root}${install_base}/lib/$(basename "${dep}")"
        if [[ ! -e "${target}" ]]; then
            cp -L "${dep}" "${target}"
        fi
    done
}

collect_ldd_deps() {
    local elf output
    while IFS= read -r -d '' elf; do
        if ! file -b "${elf}" | grep -Eq 'ELF .*(executable|shared object|pie executable)'; then
            continue
        fi
        output="$(env -u LD_LIBRARY_PATH LD_LIBRARY_PATH="${package_root}${install_base}/lib" ldd "${elf}" 2>&1 || true)"
        if grep -q 'not found' <<<"${output}"; then
            printf '%s\n' "${output}" >&2
            die "unresolved runtime dependency while scanning ${elf}"
        fi
        awk '/=> \/.* \(/ { print $3 } /^\// { print $1 }' <<<"${output}"
    done < <(find "${package_root}${install_base}/bin" "${package_root}${install_base}/lib" "${package_root}${install_base}/plugins" -type f \( -perm -0100 -o -name '*.so*' \) -print0 2>/dev/null)
}

copy_runtime_deps() {
    local copied_any dep target deps_file
    deps_file="$(mktemp "${TMPDIR:-/tmp}/wkhtmltox-deps.XXXXXX")"
    copy_toolchain_runtime_deps
    copied_any=true
    while [[ "${copied_any}" == true ]]; do
        copied_any=false
        collect_ldd_deps | sort -u > "${deps_file}"
        while IFS= read -r dep; do
            [[ -f "${dep}" ]] || continue
            if [[ "${dep}" =~ ${skip_regex} ]]; then
                continue
            fi
            case "${dep}" in
                "${package_root}${install_base}/lib"/*)
                    continue
                    ;;
                "${install_base}"/*|/usr/local/*)
                    die "refusing to bundle host-contaminated dependency: ${dep}"
                    ;;
            esac
            target="${package_root}${install_base}/lib/$(basename "${dep}")"
            if [[ ! -e "${target}" ]]; then
                cp -L "${dep}" "${target}"
                copied_any=true
            fi
        done < "${deps_file}"
    done
    rm -f "${deps_file}"
}
copy_runtime_deps

set_private_rpaths() {
    local elf
    while IFS= read -r -d '' elf; do
        if file -b "${elf}" | grep -Eq 'ELF .*(executable|shared object|pie executable)'; then
            patchelf --set-rpath "${install_base}/lib" "${elf}"
        fi
    done < <(find "${package_root}${install_base}/bin" "${package_root}${install_base}/lib" "${package_root}${install_base}/plugins" -type f -print0 2>/dev/null)
}
set_private_rpaths

validate_runpaths() {
    local elf dynamic
    while IFS= read -r -d '' elf; do
        if ! file -b "${elf}" | grep -Eq 'ELF .*(executable|shared object|pie executable)'; then
            continue
        fi
        dynamic="$(readelf -d "${elf}" 2>/dev/null || true)"
        if grep -q '(NEEDED)' <<<"${dynamic}" && ! grep -Eq "\((RUNPATH|RPATH)\).*\[${install_base}/lib\]" <<<"${dynamic}"; then
            die "missing ${install_base}/lib RUNPATH/RPATH on ${elf}"
        fi
    done < <(find "${package_root}${install_base}/bin" "${package_root}${install_base}/lib" "${package_root}${install_base}/plugins" -type f -print0 2>/dev/null)
}
validate_runpaths

validate_libstdcxx_symbols() {
    local libstdcxx version missing=0
    local -a required provided
    libstdcxx="${package_root}${install_base}/lib/libstdc++.so.6"
    mapfile -t required < <(
        find "${package_root}${install_base}/bin" "${package_root}${install_base}/lib" "${package_root}${install_base}/plugins" -type f -print0 2>/dev/null |
            while IFS= read -r -d '' elf; do
                file -b "${elf}" | grep -Eq 'ELF .*(executable|shared object|pie executable)' || continue
                readelf --version-info "${elf}" 2>/dev/null | grep -o 'GLIBCXX_[0-9][0-9.]*' || true
            done | sort -Vu
    )
    ((${#required[@]})) || return 0
    [[ -f "${libstdcxx}" ]] || die "packaged ELF files require GLIBCXX symbols but ${libstdcxx} is missing"
    mapfile -t provided < <(strings "${libstdcxx}" | grep -o '^GLIBCXX_[0-9][0-9.]*$' | sort -Vu)
    for version in "${required[@]}"; do
        if ! printf '%s\n' "${provided[@]}" | grep -Fxq "${version}"; then
            echo "missing ${version} in bundled libstdc++.so.6" >&2
            missing=1
        fi
    done
    ((missing == 0)) || die "bundled libstdc++.so.6 does not satisfy packaged binaries"
}
validate_libstdcxx_symbols

validate_full_functionality_binaries() {
    local tool version_output help_output
    for tool in wkhtmltopdf wkhtmltoimage; do
        version_output="$(env -i PATH=/usr/bin:/bin LD_LIBRARY_PATH="${package_root}${install_base}/lib" FONTCONFIG_FILE="${package_root}${install_base}/etc/fonts/fonts.conf" QT_QPA_PLATFORM=offscreen "${package_root}${install_base}/bin/${tool}.bin" --version 2>&1)"
        grep -Fq "${release_version} (with patched Qt)" <<<"${version_output}" || die "${tool} is not a full patched-Qt ${release_version} build: ${version_output}"
    done
    help_output="$(env -i PATH=/usr/bin:/bin LD_LIBRARY_PATH="${package_root}${install_base}/lib" FONTCONFIG_FILE="${package_root}${install_base}/etc/fonts/fonts.conf" QT_QPA_PLATFORM=offscreen "${package_root}${install_base}/bin/wkhtmltopdf.bin" --extended-help 2>&1)"
    if grep -Eq 'Reduced Functionality|not using wkhtmltopdf patched Qt' <<<"${help_output}"; then
        die "wkhtmltopdf help reports reduced functionality"
    fi
}
validate_full_functionality_binaries

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
Depends: libc6 (>= ${libc_version}), imagemagick
Conflicts: wkhtmltopdf
Replaces: wkhtmltopdf
Provides: wkhtmltopdf
Homepage: https://wkhtmltopdf.org/
Description: convert HTML to PDF and images using bundled patched Qt WebKit
 wkhtmltox contains wkhtmltopdf and wkhtmltoimage command line tools plus
 libwkhtmltox. Runtime Qt/WebKit libraries and baseline fonts are bundled;
 ImageMagick is used for AVIF image decoding on amd64 Debian, Ubuntu, and Linux
 Mint systems with a compatible glibc. Release packages are built only with
 wkhtmltopdf patched Qt to provide full functionality.
EOF

cat > "${package_root}/DEBIAN/preinst" <<'EOF'
#!/bin/sh
set -e
conf=/etc/ld.so.conf.d/wkhtmltox.conf
if [ -f "$conf" ] && grep -Fxq '/opt/wkhtmltox/lib' "$conf"; then
    rm -f "$conf"
fi
EOF
chmod 0755 "${package_root}/DEBIAN/preinst"

cat > "${package_root}/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
conf=/etc/ld.so.conf.d/wkhtmltox.conf
if [ -f "$conf" ] && grep -Fxq '/opt/wkhtmltox/lib' "$conf"; then
    rm -f "$conf"
fi

stamp=$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || echo now)
for tool in wkhtmltopdf wkhtmltoimage; do
    path=/usr/local/bin/$tool
    packaged=/usr/bin/$tool
    if [ -e "$path" ] || [ -L "$path" ]; then
        if [ "$(readlink -f "$path" 2>/dev/null || true)" = "$packaged" ]; then
            continue
        fi
        backup="$path.wkhtmltox-shadowed.$stamp"
        mv "$path" "$backup"
        ln -s "$packaged" "$path"
        echo "wkhtmltox: moved shadowing $path to $backup and linked $path to $packaged" >&2
    fi
done

backup_dir=/usr/local/lib/wkhtmltox-shadowed-$stamp
moved_libs=false
for path in /usr/local/lib/libwkhtmltox.so*; do
    if [ -e "$path" ] || [ -L "$path" ]; then
        mkdir -p "$backup_dir"
        mv "$path" "$backup_dir/"
        moved_libs=true
    fi
done
if [ "$moved_libs" = true ]; then
    echo "wkhtmltox: moved shadowing /usr/local/lib/libwkhtmltox.so* files to $backup_dir" >&2
fi

if command -v ldconfig >/dev/null 2>&1; then
    ldconfig
fi
EOF
chmod 0755 "${package_root}/DEBIAN/postinst"

cat > "${package_root}/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
for tool in wkhtmltopdf wkhtmltoimage; do
    path=/usr/local/bin/$tool
    if [ -L "$path" ] && [ "$(readlink -f "$path" 2>/dev/null || true)" = "/usr/bin/$tool" ]; then
        rm -f "$path"
    fi
done
if command -v ldconfig >/dev/null 2>&1; then
    ldconfig
fi
EOF
chmod 0755 "${package_root}/DEBIAN/postrm"

find "${package_root}" -type d -exec chmod 0755 {} +
"${system_tool_env[@]}" dpkg-deb --root-owner-group --build "${package_root}" "${release_output}/linux-deb/${package_name}.deb"
(
    cd "${release_output}"
    find linux-deb -maxdepth 1 -type f -name '*.deb' -print | sort | xargs sha256sum > checksums-linux-deb.txt
)
