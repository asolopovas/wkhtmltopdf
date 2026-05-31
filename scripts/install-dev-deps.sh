#!/usr/bin/env bash
set -Eeuo pipefail

script_name=$(basename -- "$0")
qt_version=5
dry_run=0

usage() {
	cat <<USAGE
Usage: $script_name [--qt 4|5] [--dry-run]

Install development packages needed for local unpatched wkhtmltopdf builds on
Debian/Ubuntu systems.

Options:
  --qt 5       Install Qt 5 build dependencies (default, matches CI qt5 job)
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
)

case "$qt_version" in
5)
	packages+=(
		libqt5svg5-dev
		libqt5webkit5-dev
		libqt5xmlpatterns5-dev
		qt5-qmake
		qtbase5-dev
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
	print_command "${apt_install_runner[@]}" install -y --no-install-recommends "${packages[@]}"
	exit 0
fi

"${apt_runner[@]}" update
"${apt_install_runner[@]}" install -y --no-install-recommends "${packages[@]}"
