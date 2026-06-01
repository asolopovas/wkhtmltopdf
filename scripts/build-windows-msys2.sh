#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"

release_version="${RELEASE_VERSION:-$(tr -d '[:space:]' < "${REPO_DIR}/VERSION")}"
release_version="${release_version//[[:space:]]/}"
release_output="${RELEASE_OUTPUT:-${REPO_DIR}/releases/${release_version}}"
case "${release_output}" in
    /*) ;;
    *) release_output="${REPO_DIR}/${release_output}" ;;
esac
log_root="${WKHTMLTOX_LOG_DIR:-${REPO_DIR}/tmp/logs}"
mkdir -p "${log_root}"
log_file="${log_root}/build-windows-msys2-$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
touch "${log_file}"
echo "build-windows-msys2: logging to ${log_file}"
exec > >(tee -a "${log_file}") 2>&1
echo "build-windows-msys2: logging to ${log_file}"

qmake_bin="${QMAKE:-}"
if [[ -z "${qmake_bin}" ]]; then
    for candidate in qmake qmake-qt5 qmake.exe qmake-qt5.exe /ucrt64/bin/qmake-qt5.exe /mingw64/bin/qmake-qt5.exe; do
        if command -v "${candidate}" >/dev/null 2>&1; then
            qmake_bin="${candidate}"
            break
        fi
    done
fi
if [[ -z "${qmake_bin}" ]]; then
    echo "qmake not found; install a wkhtmltopdf patched Qt toolchain" >&2
    exit 127
fi

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
Release installers must be full-functionality builds; refusing to create a reduced-functionality Windows package.
Use QMAKE=/path/to/patched-qt/bin/qmake from the wkhtmltopdf patched Qt 4.8 tree.
EOF
        exit 2
    fi
}

require_patched_qt

makensis_bin="${MAKENSIS:-}"
if [[ -z "${makensis_bin}" ]]; then
    for candidate in makensis makensis.exe /ucrt64/bin/makensis.exe /mingw64/bin/makensis.exe; do
        if command -v "${candidate}" >/dev/null 2>&1; then
            makensis_bin="${candidate}"
            break
        fi
    done
fi
if [[ -z "${makensis_bin}" ]]; then
    echo "makensis not found; install the MSYS2 NSIS package" >&2
    exit 127
fi

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

case "${release_version}" in
    *[!0-9A-Za-z.+:~_-]*|'')
        echo "invalid RELEASE_VERSION: ${release_version}" >&2
        exit 2
        ;;
esac

build_dir="${REPO_DIR}/build-windows-msys2"
stage_dir="${REPO_DIR}/package/wkhtmltox"
rm -rf "${build_dir}" "${stage_dir}" "${release_output}/windows-exe"
mkdir -p "${build_dir}" "${stage_dir}" "${release_output}/windows-exe"

export WKHTMLTOX_VERSION="${release_version}"
# Keep qmake variables such as INSTALLBASE=/wkhtmltox from being rewritten as
# Windows paths by MSYS2 argument conversion.
export MSYS2_ARG_CONV_EXCL="${MSYS2_ARG_CONV_EXCL:-};INSTALLBASE="
cd "${build_dir}"
"${qmake_bin}" "${REPO_DIR}/wkhtmltopdf.pro" CONFIG+=release CONFIG+=silent INSTALLBASE=/wkhtmltox

preseed_qmake_resource_object() {
    local project_dir="$1"
    local target_name="$2"
    local empty_c="${project_dir}/.empty-resource.c"

    mkdir -p "${project_dir}/release" "${project_dir}/debug"
    : > "${empty_c}"
    for build_config in release debug; do
        local resource_object="${project_dir}/${build_config}/${target_name}_resource_res.o"
        if [[ ! -e "${resource_object}" ]]; then
            "${CC:-gcc}" -x c -c "${empty_c}" -o "${resource_object}"
        fi
    done
    rm -f "${empty_c}"
}

# qmake warns when its auto-generated Windows resource object does not exist
# before the subproject Makefile is generated. Preseed valid empty objects;
# qmake then writes the .rc files and make rebuilds these objects normally.
preseed_qmake_resource_object "${build_dir}/src/lib" wkhtmltox
preseed_qmake_resource_object "${build_dir}/src/pdf" wkhtmltopdf
preseed_qmake_resource_object "${build_dir}/src/image" wkhtmltoimage

# Build the library first and copy any MinGW import library beside the DLL so
# the application subprojects can resolve -lwkhtmltox.
make -j"${make_jobs}" sub-src-lib-make_first-ordered
mkdir -p "${build_dir}/bin"
mapfile -t import_libs < <(find "${build_dir}/src/lib" "${build_dir}/bin" -type f \( -name 'libwkhtmltox*.a' -o -name 'wkhtmltox*.a' \) -print | sort -u)
if [[ "${#import_libs[@]}" -gt 0 ]]; then
    for import_lib in "${import_libs[@]}"; do
        if [[ "$(dirname "${import_lib}")" != "${build_dir}/bin" ]]; then
            cp "${import_lib}" "${build_dir}/bin/"
        fi
    done
else
    echo "no wkhtmltox import library found after library build" >&2
    find "${build_dir}/src/lib" "${build_dir}/bin" -maxdepth 3 -type f -print >&2 || true
    exit 1
fi

make -j"${make_jobs}" sub-src-pdf-make_first-ordered sub-src-image-make_first-ordered
make install INSTALL_ROOT="${REPO_DIR}/package"

if [[ ! -x "${stage_dir}/bin/wkhtmltopdf.exe" || ! -x "${stage_dir}/bin/wkhtmltoimage.exe" ]]; then
    echo "expected installed executables under ${stage_dir}/bin" >&2
    find "${REPO_DIR}/package" -maxdepth 4 -type f -print >&2 || true
    exit 1
fi

windeployqt_bin="${WINDEPLOYQT:-}"
if [[ -z "${windeployqt_bin}" ]]; then
    for candidate in windeployqt windeployqt-qt5 windeployqt.exe windeployqt-qt5.exe /ucrt64/bin/windeployqt-qt5.exe /mingw64/bin/windeployqt-qt5.exe; do
        if command -v "${candidate}" >/dev/null 2>&1; then
            windeployqt_bin="${candidate}"
            break
        fi
    done
fi
if [[ -z "${windeployqt_bin}" ]]; then
    echo "windeployqt not found; install the MSYS2 Qt 5 tools package" >&2
    exit 127
fi

# Some MSYS2 Qt 5 windeployqt builds still look specifically for qmake.exe.
qmake_path="$(command -v "${qmake_bin}")"
qmake_dir="$(dirname "${qmake_path}")"
if [[ ! -e "${qmake_dir}/qmake.exe" && -e "${qmake_dir}/qmake-qt5.exe" ]]; then
    cp "${qmake_dir}/qmake-qt5.exe" "${qmake_dir}/qmake.exe"
fi

windeployqt_args=(--release --compiler-runtime)
"${windeployqt_bin}" "${windeployqt_args[@]}" "${stage_dir}/bin/wkhtmltox.dll"
"${windeployqt_bin}" "${windeployqt_args[@]}" "${stage_dir}/bin/wkhtmltopdf.exe"
"${windeployqt_bin}" "${windeployqt_args[@]}" "${stage_dir}/bin/wkhtmltoimage.exe"

copy_msys2_runtime_deps() {
    local copied_any=true
    while [[ "${copied_any}" == true ]]; do
        copied_any=false
        while IFS= read -r dependency; do
            local target
            target="${stage_dir}/bin/$(basename "${dependency}")"
            if [[ ! -e "${target}" ]]; then
                cp "${dependency}" "${target}"
                copied_any=true
            fi
        done < <(
            find "${stage_dir}/bin" -type f \( -name '*.exe' -o -name '*.dll' \) -print0 |
                xargs -0 -r ldd 2>/dev/null |
                awk '/=> \/ucrt64\/bin\// { print $3 } /^\/ucrt64\/bin\// { print $1 }' |
                sort -u
        )
    done
}

copy_msys2_runtime_deps

cp "${REPO_DIR}/LICENSE" "${stage_dir}/LICENSE.txt"
cp "${REPO_DIR}/README.md" "${stage_dir}/README.txt"

validate_full_functionality_binaries() {
    local tool version_output help_output
    for tool in wkhtmltopdf wkhtmltoimage; do
        version_output="$("${stage_dir}/bin/${tool}.exe" --version 2>&1)"
        grep -Fq "${release_version} (with patched Qt)" <<<"${version_output}" || {
            echo "${tool}.exe is not a full patched-Qt ${release_version} build: ${version_output}" >&2
            exit 1
        }
    done
    help_output="$("${stage_dir}/bin/wkhtmltopdf.exe" --extended-help 2>&1)"
    if grep -Eq 'Reduced Functionality|not using wkhtmltopdf patched Qt' <<<"${help_output}"; then
        echo "wkhtmltopdf.exe help reports reduced functionality" >&2
        exit 1
    fi
}
validate_full_functionality_binaries

installer="${release_output}/windows-exe/wkhtmltox-${release_version}-1.windows-ucrt64-installer.exe"
source_dir_win="$(cygpath -w "${stage_dir}")"
installer_win="$(cygpath -w "${installer}")"
nsi_win="$(cygpath -w "${REPO_DIR}/scripts/wkhtmltox.nsi")"
MSYS2_ARG_CONV_EXCL='*' "${makensis_bin}" \
    "/DVERSION=${release_version}" \
    "/DSOURCE_DIR=${source_dir_win}" \
    "/DOUT_FILE=${installer_win}" \
    "${nsi_win}"

(
    cd "${release_output}"
    find windows-exe -maxdepth 1 -type f -name '*.exe' -print | sort | xargs sha256sum > checksums-windows-exe.txt
)
