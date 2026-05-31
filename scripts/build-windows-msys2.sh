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
    echo "qmake not found; install the MSYS2 Qt 5 base package" >&2
    exit 127
fi
make_jobs="${MAKE_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '2')}"

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
cd "${build_dir}"
"${qmake_bin}" "${REPO_DIR}/wkhtmltopdf.pro" CONFIG+=release CONFIG+=silent INSTALLBASE=/wkhtmltox
make -j"${make_jobs}"
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

"${windeployqt_bin}" --release --compiler-runtime "${stage_dir}/bin/wkhtmltopdf.exe"
"${windeployqt_bin}" --release --compiler-runtime "${stage_dir}/bin/wkhtmltoimage.exe"

cp "${REPO_DIR}/LICENSE" "${stage_dir}/LICENSE.txt"
cp "${REPO_DIR}/README.md" "${stage_dir}/README.txt"

(
    cd "${stage_dir}/bin"
    ./wkhtmltopdf.exe --version
    ./wkhtmltoimage.exe --version
)
