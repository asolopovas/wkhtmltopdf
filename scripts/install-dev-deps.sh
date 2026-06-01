#!/usr/bin/env bash
set -Eeuo pipefail

script_name=$(basename -- "$0")
qt_version=5
dry_run=0

usage() {
	cat <<USAGE
Usage: $script_name [--qt 4|5] [--dry-run]

Install development packages needed for local unpatched wkhtmltopdf builds and
smoke tests on Debian/Ubuntu systems.

Options:
  --qt 5       Install Qt 5 build dependencies (default)
  --qt 4       Install legacy Qt 4 build dependencies (for old distributions)
  --dry-run    Print the apt-get commands without running them
  -h, --help   Show this help
USAGE
}

error() {
	echo "ERROR: $*" >&2
	exit 1
}

print_command() {
	local first=1
	printf '  '
	for arg in "$@"; do
		if ((first)); then
			first=0
		else
			printf ' '
		fi
		printf '%q' "$arg"
	done
	printf '\n'
}

while (($#)); do
	case "$1" in
	--qt)
		(($# >= 2)) || error "--qt requires 4 or 5"
		qt_version="$2"
		shift 2
		;;
	--qt=*)
		qt_version="${1#--qt=}"
		shift
		;;
	--dry-run)
		dry_run=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		error "unknown option: $1"
		;;
	esac
done

case "$qt_version" in
4 | 5) ;;
*) error "unsupported Qt version '$qt_version' (expected 4 or 5)" ;;
esac

command -v apt-get >/dev/null 2>&1 || error "apt-get not found; install dependencies manually for your OS"

apt_runner=(apt-get)
apt_install_runner=(env DEBIAN_FRONTEND=noninteractive apt-get)
if [[ ${EUID} -ne 0 ]]; then
	command -v sudo >/dev/null 2>&1 || error "sudo not found; rerun as root or install sudo"
	apt_runner=(sudo apt-get)
	apt_install_runner=(sudo env DEBIAN_FRONTEND=noninteractive apt-get)
fi

packages=(
	build-essential
	ca-certificates
	imagemagick
	python3
)
optional_packages=()

case "$qt_version" in
5)
	packages+=(
		libqt5svg5-dev
		libqt5webkit5-dev
		libqt5xmlpatterns5-dev
		qt5-qmake
		qtbase5-dev
	)
	optional_packages+=(
		qt5-avif-image-plugin
	)
	;;
4)
	packages+=(
		libqtwebkit-dev
	)
	;;
esac

if ((dry_run)); then
	printf 'Would run:\n'
	print_command "${apt_runner[@]}" update
	print_command "${apt_install_runner[@]}" install -y --no-remove --fix-broken
	print_command "${apt_install_runner[@]}" install -y --no-install-recommends "${packages[@]}"
	if ((${#optional_packages[@]})); then
		print_command "${apt_install_runner[@]}" install -y --no-install-recommends "${optional_packages[@]}"
	fi
	exit 0
fi

"${apt_runner[@]}" update
# A previously installed local wkhtmltox package may leave apt in a broken
# state until its runtime dependencies are installed. Heal dependency-only
# breakage first so installing already-present development packages still works;
# --no-remove prevents apt from silently removing local packages to proceed.
"${apt_install_runner[@]}" install -y --no-remove --fix-broken
"${apt_install_runner[@]}" install -y --no-install-recommends "${packages[@]}"
if ((${#optional_packages[@]})); then
	if ! "${apt_install_runner[@]}" install -y --no-install-recommends "${optional_packages[@]}"; then
		echo "WARNING: optional Qt AVIF plugin package is unavailable for system Qt 5 builds." >&2
	fi
fi
