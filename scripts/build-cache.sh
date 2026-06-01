#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
VERSION="${RELEASE_VERSION:-$(tr -d '[:space:]' < "${REPO_DIR}/VERSION")}" 
VERSION="${VERSION//[[:space:]]/}"
CACHE_RELEASE="${BUILD_CACHE_RELEASE:-build-cache-${VERSION}}"
CACHE_DIR="${BUILD_CACHE_DIR:-${REPO_DIR}/artifacts/build-cache}"
LINUX_CACHE_SOURCE="${LINUX_BUILD_CACHE_SOURCE:-${REPO_DIR}/tmp/builds/focal-amd64}"
WINDOWS_CACHE_SOURCE="${WINDOWS_BUILD_CACHE_SOURCE:-/tmp/wkhtmltopdf-packaging/targets/mxe-cross-win64}"
REPO_SLUG="${GITHUB_REPOSITORY:-asolopovas/wkhtmltopdf}"

usage() {
    cat <<EOF
Usage: $(basename "$0") save|restore|upload

save    Create compressed patched Qt/QtWebKit build-cache archives.
restore Restore cache archives into tmp/builds and packaging targets.
upload  Upload cache archives to GitHub release ${CACHE_RELEASE}.

Environment:
  RELEASE_VERSION=${VERSION}
  BUILD_CACHE_RELEASE=${CACHE_RELEASE}
  BUILD_CACHE_DIR=${CACHE_DIR}
  LINUX_BUILD_CACHE_SOURCE=${LINUX_CACHE_SOURCE}
  WINDOWS_BUILD_CACHE_SOURCE=${WINDOWS_CACHE_SOURCE}
  GITHUB_REPOSITORY=${REPO_SLUG}
EOF
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: $1 is required" >&2
        exit 1
    }
}

linux_archive="${CACHE_DIR}/wkhtmltox-${VERSION}-patched-qt-linux-focal-amd64-buildcache.tar.zst"
windows_archive="${CACHE_DIR}/wkhtmltox-${VERSION}-patched-qt-mxe-cross-win64-buildcache.tar.zst"

write_readme() {
    cat > "${CACHE_DIR}/README-build-cache-${VERSION}.txt" <<EOF
wkhtmltox ${VERSION} build caches
created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
repo: ${REPO_SLUG}
commit: $(git -C "${REPO_DIR}" rev-parse HEAD)

These archives avoid rebuilding patched Qt 4.8 / QtWebKit.
Restore from repository root:

  scripts/build-cache.sh restore

Manual restore:

  tar --zstd -xf $(basename "${linux_archive}") -C tmp/builds
  tar --zstd -xf $(basename "${windows_archive}") -C /tmp/wkhtmltopdf-packaging/targets

Use all CPU cores when resuming builds:

  MAKE_JOBS=\$(nproc) scripts/build-linux-deb.sh
  cd /tmp/wkhtmltopdf-packaging && python3 ./build package-docker --iteration 1 mxe-cross-win64 /path/to/wkhtmltopdf

Do not use --clean unless you intentionally want to rebuild QtWebKit.
EOF
}

save_cache() {
    require_command tar
    require_command zstd
    [[ -d "${LINUX_CACHE_SOURCE}" ]] || { echo "ERROR: missing ${LINUX_CACHE_SOURCE}" >&2; exit 1; }
    [[ -d "${WINDOWS_CACHE_SOURCE}" ]] || { echo "ERROR: missing ${WINDOWS_CACHE_SOURCE}" >&2; exit 1; }
    mkdir -p "${CACHE_DIR}"
    tar -C "$(dirname "${LINUX_CACHE_SOURCE}")" --zstd -cf "${linux_archive}" "$(basename "${LINUX_CACHE_SOURCE}")"
    tar -C "$(dirname "${WINDOWS_CACHE_SOURCE}")" --zstd -cf "${windows_archive}" "$(basename "${WINDOWS_CACHE_SOURCE}")"
    write_readme
    (cd "${CACHE_DIR}" && sha256sum -- ./*.tar.zst "README-build-cache-${VERSION}.txt" > checksums-build-cache.txt)
    ls -lh "${CACHE_DIR}"
}

restore_cache() {
    require_command tar
    require_command zstd
    [[ -f "${linux_archive}" ]] || { echo "ERROR: missing ${linux_archive}" >&2; exit 1; }
    [[ -f "${windows_archive}" ]] || { echo "ERROR: missing ${windows_archive}" >&2; exit 1; }
    mkdir -p "${REPO_DIR}/tmp/builds" /tmp/wkhtmltopdf-packaging/targets
    tar -C "${REPO_DIR}/tmp/builds" --zstd -xf "${linux_archive}"
    tar -C /tmp/wkhtmltopdf-packaging/targets --zstd -xf "${windows_archive}"
}

upload_cache() {
    require_command gh
    [[ -f "${linux_archive}" && -f "${windows_archive}" ]] || save_cache
    if ! gh release view "${CACHE_RELEASE}" --repo "${REPO_SLUG}" >/dev/null 2>&1; then
        gh release create "${CACHE_RELEASE}" \
            --repo "${REPO_SLUG}" \
            --target "$(git -C "${REPO_DIR}" rev-parse HEAD)" \
            --title "wkhtmltox ${VERSION} build cache" \
            --notes "Build-cache artifacts for maintainers only. End users should install assets from the ${VERSION}/latest release." \
            --prerelease
    fi
    gh release upload "${CACHE_RELEASE}" "${CACHE_DIR}"/* --clobber --repo "${REPO_SLUG}"
}

case "${1:-}" in
    save) save_cache ;;
    restore) restore_cache ;;
    upload) upload_cache ;;
    -h|--help|'') usage; [[ "${1:-}" ]] && exit 0 || exit 2 ;;
    *) usage >&2; exit 2 ;;
esac
