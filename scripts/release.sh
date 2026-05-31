#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"

usage() {
    cat <<'EOF'
Usage: scripts/release.sh [OPTIONS]

Create a stable release commit/tag from VERSION. Tags intentionally do not use a
"v" prefix because this repository's historical tags are 0.12.x.

Options:
  --bump [patch|minor|major|X.Y.Z]  Bump VERSION's base version, or use X.Y.Z
  --version X.Y.Z                   Release an explicit version
  --output DIR                      Build artifacts into DIR (default: releases/X.Y.Z)
  --no-build                        Skip local package build
  --push / --no-push                Push commit and tags to origin (default: push)
  --upload / --no-upload            Upload artifacts with gh release (default: no-upload)
  --dry-run                         Print the resolved plan only
  -h, --help                        Show this help

Examples:
  make release VERSION_OVERRIDE=0.13.0
  make release BUMP=patch
  make release RELEASE_ARGS='--bump minor --no-push'
EOF
}

err() {
    echo "release: $*" >&2
    exit 1
}

trim_version() {
    local value="$1"
    value="${value#v}"
    value="${value%%-*}"
    printf '%s' "${value}"
}

validate_version() {
    local value="$1"
    [[ "${value}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || err "invalid version: ${value}"
}

bump_version() {
    local base="$1"
    local bump="$2"
    local major minor patch
    IFS=. read -r major minor patch <<<"${base}"
    validate_version "${base}"
    case "${bump}" in
        patch) printf '%s.%s.%s' "${major}" "${minor}" "$((patch + 1))" ;;
        minor) printf '%s.%s.0' "${major}" "$((minor + 1))" ;;
        major) printf '%s.0.0' "$((major + 1))" ;;
        v[0-9]*.[0-9]*.[0-9]*|[0-9]*.[0-9]*.[0-9]*) trim_version "${bump}" ;;
        *) err "invalid bump: ${bump}" ;;
    esac
}

bump=""
version_override=""
output_dir=""
push=true
build=true
upload=false
dry_run=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bump)
            if [[ $# -ge 2 && "$2" != --* ]]; then
                bump="$2"
                shift 2
            else
                bump=patch
                shift
            fi
            ;;
        --bump=*) bump="${1#--bump=}"; [[ -n "${bump}" ]] || bump=patch; shift ;;
        --version) [[ $# -ge 2 ]] || err "--version requires a value"; version_override="$2"; shift 2 ;;
        --version=*) version_override="${1#--version=}"; [[ -n "${version_override}" ]] || err "--version requires a value"; shift ;;
        --output) [[ $# -ge 2 ]] || err "--output requires a value"; output_dir="$2"; shift 2 ;;
        --output=*) output_dir="${1#--output=}"; [[ -n "${output_dir}" ]] || err "--output requires a value"; shift ;;
        --push) push=true; shift ;;
        --no-push) push=false; shift ;;
        --build) build=true; shift ;;
        --no-build) build=false; shift ;;
        --upload) upload=true; shift ;;
        --no-upload) upload=false; shift ;;
        --dry-run) dry_run=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) err "unknown argument: $1" ;;
    esac
done

cd "${REPO_DIR}"

current="$(tr -d '[:space:]' < VERSION)"
base="$(trim_version "${current}")"
validate_version "${base}"

if [[ -n "${version_override}" && -n "${bump}" ]]; then
    err "use either --version or --bump, not both"
fi

if [[ -n "${version_override}" ]]; then
    release_version="$(trim_version "${version_override}")"
elif [[ -n "${bump}" ]]; then
    release_version="$(bump_version "${base}" "${bump}")"
else
    release_version="${base}"
fi
validate_version "${release_version}"

if [[ -z "${output_dir}" ]]; then
    output_dir="releases/${release_version}"
fi

if [[ "${dry_run}" == true ]]; then
    echo "release: current=${current} version=${release_version} output=${output_dir} build=${build} push=${push} upload=${upload}"
    exit 0
fi

if [[ "$(git rev-parse --show-toplevel)" != "${REPO_DIR}" ]]; then
    err "not running at repository root"
fi

git diff --quiet || err "tracked files changed; commit or stash before release"
git diff --cached --quiet || err "staged changes exist; commit or stash before release"
! git rev-parse -q --verify "refs/tags/${release_version}" >/dev/null || err "tag exists: ${release_version}"

printf '%s\n' "${release_version}" > VERSION

if [[ "${build}" == true ]]; then
    make release-build RELEASE_VERSION="${release_version}" RELEASE_OUTPUT="${output_dir}"
fi

changed_files="$(git diff --name-only)"
if [[ "${changed_files}" != "VERSION" ]]; then
    echo "release: unexpected tracked changes after build:" >&2
    git diff --name-only >&2
    exit 1
fi

git add VERSION
git commit -m "Release ${release_version}"
git tag "${release_version}"
if git rev-parse -q --verify refs/tags/latest >/dev/null; then
    git tag -d latest >/dev/null
fi
git tag latest

if [[ "${push}" == true ]]; then
    git push origin HEAD
    git push origin "${release_version}"
    git push origin latest --force
fi

if [[ "${upload}" == true ]]; then
    command -v gh >/dev/null || err "gh is required for --upload"
    mapfile -t artifacts < <(find "${output_dir}" -type f -print | sort)
    [[ "${#artifacts[@]}" -gt 0 ]] || err "no artifacts found in ${output_dir}"
    if gh release view "${release_version}" >/dev/null 2>&1; then
        gh release upload "${release_version}" "${artifacts[@]}" --clobber
    else
        gh release create "${release_version}" "${artifacts[@]}" \
            --target "$(git rev-parse HEAD)" \
            --title "wkhtmltox ${release_version}" \
            --notes "wkhtmltox ${release_version}"
    fi
fi

echo "release: ${release_version} ready"
