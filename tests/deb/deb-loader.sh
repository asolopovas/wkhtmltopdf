#!/usr/bin/env bash
set -Eeuo pipefail

script_name="$(basename -- "$0")"
expected_version="${EXPECTED_WKHTMLTOX_DEB_VERSION:-0.13.0-1.linux}"
install_base="/opt/wkhtmltox"
# A previously installed broken wkhtmltox package can put /opt/wkhtmltox/lib
# into ld.so.cache. Keep Debian/binutils tooling on system libraries so this
# test can diagnose and replace that broken package instead of crashing first.
system_ld_library_path="/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:/lib:/usr/lib"
export LD_LIBRARY_PATH="${system_ld_library_path}"

usage() {
    cat <<EOF
Usage: ${script_name} PATH-TO-WKHTMLTOX.deb

Validate and install a wkhtmltox Debian package, including loader isolation
checks for stale /usr/local libraries and private /opt runtime libraries.
EOF
}

error() {
    echo "ERROR: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || error "$1 is required"
}

as_root() {
    if [[ ${EUID} -eq 0 ]]; then
        env LD_LIBRARY_PATH="${system_ld_library_path}" "$@"
    else
        require_command sudo
        sudo env LD_LIBRARY_PATH="${system_ld_library_path}" "$@"
    fi
}

if [[ $# -ne 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    [[ $# -eq 1 ]] && exit 0 || exit 2
fi

deb="$1"
[[ -f "${deb}" ]] || error "package not found: ${deb}"

for cmd in dpkg-deb readelf file ldd ldconfig grep awk env; do
    require_command "${cmd}"
done

version="$(dpkg-deb -f "${deb}" Version)"
[[ "${version}" == "${expected_version}" ]] || error "deb version is ${version}, expected ${expected_version}"

deb_contents="$(dpkg-deb -c "${deb}")"
if grep -Fq '/etc/ld.so.conf.d/wkhtmltox.conf' <<<"${deb_contents}"; then
    error "package must not globally publish ${install_base}/lib via /etc/ld.so.conf.d/wkhtmltox.conf"
fi

extract_dir="$(mktemp -d "${TMPDIR:-/tmp}/wkhtmltox-deb-loader.XXXXXX")"
created_shadow=""
cleanup() {
    if [[ -n "${created_shadow}" ]]; then
        as_root rm -f "${created_shadow}" || true
        as_root ldconfig || true
    fi
    rm -rf "${extract_dir}"
}
trap cleanup EXIT

dpkg-deb -x "${deb}" "${extract_dir}"

check_elf_runpaths() {
    local elf dynamic missing=0
    while IFS= read -r -d '' elf; do
        if ! file -b "${elf}" | grep -Eq 'ELF .*(executable|shared object|pie executable)'; then
            continue
        fi
        dynamic="$(readelf -d "${elf}" 2>/dev/null || true)"
        if grep -q '(NEEDED)' <<<"${dynamic}" && ! grep -Eq "\((RUNPATH|RPATH)\).*\[${install_base}/lib\]" <<<"${dynamic}"; then
            echo "missing ${install_base}/lib RUNPATH/RPATH: ${elf}" >&2
            missing=1
        fi
    done < <(find "${extract_dir}${install_base}" -type f -print0)
    ((missing == 0)) || error "one or more packaged ELF files are missing private runtime paths"
}
check_elf_runpaths

as_root dpkg -i "${deb}"

pdf_version="$(env -i PATH=/usr/bin:/bin /usr/bin/wkhtmltopdf --version 2>&1)"
image_version="$(env -i PATH=/usr/bin:/bin /usr/bin/wkhtmltoimage --version 2>&1)"
case "${pdf_version}" in
    *"0.13.0 (with patched Qt)"*) ;;
    *) error "/usr/bin/wkhtmltopdf is not a full 0.13.0 patched-Qt build: ${pdf_version}" ;;
esac
case "${image_version}" in
    *"0.13.0 (with patched Qt)"*) ;;
    *) error "/usr/bin/wkhtmltoimage is not a full 0.13.0 patched-Qt build: ${image_version}" ;;
esac

opt_version="$(env -i PATH=/usr/bin:/bin "${install_base}/bin/wkhtmltopdf.bin" --version 2>&1)"
case "${opt_version}" in
    *"0.13.0 (with patched Qt)"*) ;;
    *) error "direct ${install_base}/bin/wkhtmltopdf.bin execution failed or is not patched: ${opt_version}" ;;
esac

if ldconfig -p | grep -F '/opt/wkhtmltox/lib/libstdc++.so.6' >/dev/null; then
    error "ldconfig globally exposes bundled ${install_base}/lib/libstdc++.so.6"
fi

# Simulate a stale libwkhtmltox in /usr/local without overwriting a user's file.
# Dynamically linked tools must resolve libwkhtmltox.so.0 from /opt/wkhtmltox/lib.
# Static tools have no libwkhtmltox NEEDED entry and are not vulnerable to this
# loader-shadowing case.
if readelf -d "${install_base}/bin/wkhtmltopdf.bin" 2>/dev/null | grep -Fq '[libwkhtmltox.so.0]'; then
    if [[ ! -e /usr/local/lib/libwkhtmltox.so.0 ]]; then
        libc_path="$(ldconfig -p | awk '/libc\.so\.6 .*x86-64/ { print $NF; exit }')"
        [[ -n "${libc_path}" && -f "${libc_path}" ]] || error "could not locate libc.so.6 for shadowing test"
        as_root mkdir -p /usr/local/lib
        as_root ln -s "${libc_path}" /usr/local/lib/libwkhtmltox.so.0
        created_shadow=/usr/local/lib/libwkhtmltox.so.0
        as_root ldconfig
    fi

    resolved_lib="$(ldd "${install_base}/bin/wkhtmltopdf.bin" | awk '/libwkhtmltox\.so\.0/ { print $3; exit }')"
    [[ "${resolved_lib}" == "${install_base}/lib/"* ]] || error "wkhtmltopdf.bin resolves libwkhtmltox.so.0 to ${resolved_lib:-<missing>}, expected ${install_base}/lib"
else
    echo "wkhtmltopdf.bin has no dynamic libwkhtmltox dependency; skipping shadow resolution check"
fi

help_text="$(env -i PATH=/usr/bin:/bin /usr/bin/wkhtmltopdf --extended-help 2>&1)"
if grep -Eq 'Reduced Functionality|not using wkhtmltopdf patched Qt' <<<"${help_text}"; then
    error "installed wkhtmltopdf reports reduced functionality"
fi

echo "deb loader tests passed: ${deb}"
