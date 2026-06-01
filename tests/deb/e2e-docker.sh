#!/usr/bin/env bash
set -Eeuo pipefail

script_name="$(basename -- "$0")"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cleanup_context=""

default_base_images=(
    ubuntu:20.04
    ubuntu:22.04
    ubuntu:24.04
    debian:bookworm-slim
    debian:trixie-slim
)

usage() {
    cat <<EOF
Usage: ${script_name} PATH-TO-WKHTMLTOX.deb [BASE_IMAGE ...]

Build and run a tiny Docker E2E test that installs the Debian package with
plain dpkg -i in fresh Ubuntu/Debian containers.

If no BASE_IMAGE values are supplied, the default matrix is:
  ${default_base_images[*]}
EOF
}

error() {
    echo "ERROR: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || error "$1 is required"
}

safe_tag() {
    printf '%s' "$1" | tr '/:.' '---' | tr -c 'A-Za-z0-9_.-' '-'
}

main() {
    if [[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
        [[ $# -eq 1 ]] && exit 0 || exit 2
    fi

    require_command docker

    local deb image base tag
    deb="$1"
    shift
    [[ -f "${deb}" ]] || error "package not found: ${deb}"

    local -a base_images
    if (($#)); then
        base_images=("$@")
    else
        base_images=("${default_base_images[@]}")
    fi

    cleanup_context="$(mktemp -d "${TMPDIR:-/tmp}/wkhtmltox-deb-e2e.XXXXXX")"
    trap 'rm -rf "${cleanup_context}"' EXIT

    cp "${deb}" "${cleanup_context}/wkhtmltox.deb"
    cp "${script_dir}/Dockerfile.e2e" "${cleanup_context}/Dockerfile"
    cp "${script_dir}/e2e-install-container.sh" "${cleanup_context}/e2e-install-container.sh"

    for base in "${base_images[@]}"; do
        tag="$(safe_tag "${base}")"
        image="wkhtmltox-deb-e2e:${tag}"
        echo "==> building ${image} from ${base}"
        docker build --build-arg "BASE_IMAGE=${base}" -t "${image}" "${cleanup_context}"
        echo "==> running ${image}"
        docker run --rm "${image}"
        echo "==> passed ${base}"
    done
}

main "$@"
