# Developer convenience targets.
#
# qmake generates a file named Makefile at the repository root. GNU make
# prefers GNUmakefile when present, so keep this file as a thin wrapper and
# delegate normal build/install targets to qmake's generated Makefile.

.DEFAULT_GOAL := all

QMAKE_MAKEFILE ?= Makefile
BUILD_DIR ?= build
JOBS ?= $(shell nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
BUILD_JOBS ?= $(JOBS)
QT ?= 5
ifeq ($(QT),4)
QMAKE ?= $(shell command -v qmake-qt4 2>/dev/null || command -v qmake 2>/dev/null)
else
QMAKE ?= $(shell command -v qmake 2>/dev/null)
endif
QMAKE_CONFIG ?= CONFIG+=silent
QMAKE_ARGS ?=
USE_CCACHE ?= auto
CCACHE ?= $(shell command -v ccache 2>/dev/null)
QMAKE_CCACHE_ARGS :=
ifneq ($(USE_CCACHE),0)
ifneq ($(CCACHE),)
QMAKE_CCACHE_ARGS = QMAKE_CC='$(CCACHE) gcc' QMAKE_CXX='$(CCACHE) g++'
endif
endif
prefix ?= /usr/local
PREFIX ?= $(prefix)
INSTALLBASE ?= $(PREFIX)
DESTDIR ?= $(INSTALL_ROOT)
STAGEDIR ?= $(abspath $(BUILD_DIR)/stage)
PROJECT_FILE ?= $(abspath wkhtmltopdf.pro)
DRY_RUN ?=
PYTHON ?= python3
SMOKE_TEST ?= tests/smoke/smoke.py
WKHTMLTOPDF_BINARY ?= $(abspath $(BUILD_DIR)/bin/wkhtmltopdf)
WKHTMLTOIMAGE_BINARY ?= $(abspath $(BUILD_DIR)/bin/wkhtmltoimage)
PACKAGING_REPO ?= https://github.com/wkhtmltopdf/packaging.git
PACKAGING_DIR ?= ../packaging
RELEASE_VERSION ?= $(shell tr -d '[:space:]' < VERSION | sed 's/-.*//')
RELEASE_ITERATION ?= 1
RELEASE_OUTPUT ?= releases/$(RELEASE_VERSION)
RELEASE_LINUX_TARGET ?= noble-amd64
RELEASE_WINDOWS_TARGET ?= msvc2015-win64
ifeq ($(OS),Windows_NT)
RELEASE_BUILD_TARGETS ?= release-build-windows-exe
RELEASE_TEST_TARGETS ?= release-test-windows-exe
else
RELEASE_BUILD_TARGETS ?= release-build-linux-deb
RELEASE_TEST_TARGETS ?= release-test-linux-deb
endif
RELEASE_ARGS ?=
BUMP ?=
VERSION ?=
VERSION_OVERRIDE ?= $(VERSION)
BUILD ?= true
PUSH ?= true
UPLOAD ?= false


.PHONY: all install stage uninstall clean distclean help deps install-dev configure build shadow-build test check smoke e2e release release-patch release-minor release-major release-build release-build-all release-test release-test-all release-build-linux-deb release-build-windows-exe release-test-linux-deb release-test-windows-exe ensure-packaging

all: build

install: build
	+@destdir="$(DESTDIR)"; \
	if [ -z "$$destdir" ] && [ "$(INSTALLBASE)" = "/usr/local" ] && [ "$$(id -u)" != "0" ] && [ ! -w "$(INSTALLBASE)" ]; then \
		destdir="$(STAGEDIR)"; \
		echo "INSTALLBASE=$(INSTALLBASE) is not writable; staging under DESTDIR=$$destdir"; \
		echo "For a real install, use: sudo make install PREFIX=$(INSTALLBASE)"; \
	fi; \
	$(MAKE) -C "$(BUILD_DIR)" install INSTALL_ROOT="$$destdir" || exit $$?; \
	if [ -z "$$destdir" ] && [ "$$(id -u)" = "0" ] && command -v ldconfig >/dev/null 2>&1 && { [ "$(INSTALLBASE)" = "/usr" ] || [ "$(INSTALLBASE)" = "/usr/local" ]; }; then \
		ldconfig; \
	fi

stage: DESTDIR ?= $(STAGEDIR)
stage: install

uninstall: configure
	+@$(MAKE) -C "$(BUILD_DIR)" uninstall INSTALL_ROOT="$(DESTDIR)"

clean:
	+@if [ -f "$(BUILD_DIR)/$(QMAKE_MAKEFILE)" ]; then \
		$(MAKE) -C "$(BUILD_DIR)" clean; \
	else \
		echo "Nothing to clean."; \
	fi

distclean:
	+@if [ -f "$(BUILD_DIR)/$(QMAKE_MAKEFILE)" ]; then \
		$(MAKE) -C "$(BUILD_DIR)" distclean; \
	fi
	@build_dir="$(abspath $(BUILD_DIR))"; \
	case "$$build_dir" in "/"|"$(CURDIR)") echo "Refusing to remove BUILD_DIR=$$build_dir" >&2; exit 2;; esac; \
	if [ -d "$$build_dir" ]; then rm -rf "$$build_dir"; else echo "Nothing to distclean."; fi

deps install-dev:
	./scripts/install-dev-deps.sh --qt "$(QT)" $(if $(DRY_RUN),--dry-run,)

configure:
	@if [ -z "$(QMAKE)" ]; then \
		echo "qmake not found. Run 'make install-dev' first, or set QMAKE=/path/to/qmake." >&2; \
		exit 127; \
	fi
	@mkdir -p "$(BUILD_DIR)"
	@{ \
		printf '%s\n' 'QMAKE=$(QMAKE)'; \
		printf '%s\n' 'PROJECT_FILE=$(PROJECT_FILE)'; \
		printf '%s\n' 'QMAKE_CONFIG=$(QMAKE_CONFIG)'; \
		printf '%s\n' 'QMAKE_ARGS=$(QMAKE_ARGS)'; \
		printf '%s\n' 'QMAKE_CCACHE_ARGS=$(QMAKE_CCACHE_ARGS)'; \
		printf '%s\n' 'INSTALLBASE=$(INSTALLBASE)'; \
	} > "$(BUILD_DIR)/.configure.args.tmp"
	@if [ -f "$(BUILD_DIR)/$(QMAKE_MAKEFILE)" ] && [ -f "$(BUILD_DIR)/.configure.args" ] && cmp -s "$(BUILD_DIR)/.configure.args.tmp" "$(BUILD_DIR)/.configure.args"; then \
		rm -f "$(BUILD_DIR)/.configure.args.tmp"; \
		echo "configure: up to date"; \
	else \
		(cd "$(BUILD_DIR)" && "$(QMAKE)" "$(PROJECT_FILE)" $(QMAKE_CONFIG) INSTALLBASE="$(INSTALLBASE)" $(QMAKE_CCACHE_ARGS) $(QMAKE_ARGS)) && \
		$(MAKE) -C "$(BUILD_DIR)" qmake_all && \
		mv "$(BUILD_DIR)/.configure.args.tmp" "$(BUILD_DIR)/.configure.args"; \
	fi

build shadow-build: configure
	$(MAKE) -C "$(BUILD_DIR)" -j"$(BUILD_JOBS)"

test check smoke e2e: build
	WKHTMLTOPDF_BINARY="$(WKHTMLTOPDF_BINARY)" \
	WKHTMLTOIMAGE_BINARY="$(WKHTMLTOIMAGE_BINARY)" \
	$(PYTHON) "$(SMOKE_TEST)"

release:
	@args="$(RELEASE_ARGS)"; \
	if [ -n "$(BUMP)" ]; then args="--bump $(BUMP) $$args"; fi; \
	if [ -n "$(VERSION_OVERRIDE)" ]; then args="--version $(VERSION_OVERRIDE) $$args"; fi; \
	case "$(BUILD)" in 0|false|False|FALSE|no|No|NO) args="--no-build $$args";; esac; \
	case "$(PUSH)" in 0|false|False|FALSE|no|No|NO) args="--no-push $$args";; esac; \
	case "$(UPLOAD)" in 1|true|True|TRUE|yes|Yes|YES) args="--upload $$args";; esac; \
	case "$(DRY_RUN)" in 1|true|True|TRUE|yes|Yes|YES) args="--dry-run $$args";; esac; \
	./scripts/release.sh $$args

release-patch:
	$(MAKE) release BUMP=patch $(if $(RELEASE_ARGS),RELEASE_ARGS='$(RELEASE_ARGS)',)

release-minor:
	$(MAKE) release BUMP=minor $(if $(RELEASE_ARGS),RELEASE_ARGS='$(RELEASE_ARGS)',)

release-major:
	$(MAKE) release BUMP=major $(if $(RELEASE_ARGS),RELEASE_ARGS='$(RELEASE_ARGS)',)

release-build: $(RELEASE_BUILD_TARGETS)

release-build-all: release-build-linux-deb release-build-windows-exe

release-test: $(RELEASE_TEST_TARGETS)

release-test-all: release-test-linux-deb release-test-windows-exe

ensure-packaging:
	@if [ ! -x "$(PACKAGING_DIR)/build" ]; then \
		echo "Cloning packaging into $(PACKAGING_DIR)"; \
		git clone --depth 1 "$(PACKAGING_REPO)" "$(PACKAGING_DIR)"; \
	fi

release-build-linux-deb: ensure-packaging
	$(PYTHON) scripts/patch-packaging-noble.py "$(PACKAGING_DIR)"
	@rm -rf "$(RELEASE_OUTPUT)/linux-deb"
	@mkdir -p "$(RELEASE_OUTPUT)/linux-deb"
	@rm -f "$(PACKAGING_DIR)"/targets/wkhtmltox*.deb
	cd "$(PACKAGING_DIR)" && $(PYTHON) ./build package-docker --clean --iteration "$(RELEASE_ITERATION)" "$(RELEASE_LINUX_TARGET)" "$(abspath .)"
	cp "$(PACKAGING_DIR)"/targets/wkhtmltox*.deb "$(RELEASE_OUTPUT)/linux-deb/"
	@(cd "$(RELEASE_OUTPUT)" && find linux-deb -maxdepth 1 -type f -print | sort | xargs sha256sum > checksums-linux-deb.txt)

release-build-windows-exe: ensure-packaging
	@rm -rf "$(RELEASE_OUTPUT)/windows-exe"
	@mkdir -p "$(RELEASE_OUTPUT)/windows-exe"
	@rm -f "$(PACKAGING_DIR)"/targets/wkhtmltox*.exe
	cd "$(PACKAGING_DIR)" && $(PYTHON) ./build vagrant "$(RELEASE_WINDOWS_TARGET)" --clean --version "$(RELEASE_VERSION)" "$(RELEASE_ITERATION)" "$(abspath .)"
	cp "$(PACKAGING_DIR)"/targets/wkhtmltox*.exe "$(RELEASE_OUTPUT)/windows-exe/"
	@(cd "$(RELEASE_OUTPUT)" && find windows-exe -maxdepth 1 -type f -print | sort | xargs sha256sum > checksums-windows-exe.txt)

release-test-linux-deb:
	@package="$$(ls -1 "$(RELEASE_OUTPUT)"/linux-deb/*.deb | head -n1)"; \
	[ -n "$$package" ] || { echo "release-test: no deb package in $(RELEASE_OUTPUT)/linux-deb" >&2; exit 1; }; \
	sudo apt-get update; \
	sudo apt-get install -y "$$package"; \
	WKHTMLTOPDF_BINARY=/usr/local/bin/wkhtmltopdf \
	WKHTMLTOIMAGE_BINARY=/usr/local/bin/wkhtmltoimage \
	$(PYTHON) tests/smoke/smoke.py

release-test-windows-exe:
	@installer="$$(ls -1 "$(RELEASE_OUTPUT)"/windows-exe/*.exe | head -n1)"; \
	[ -n "$$installer" ] || { echo "release-test: no exe installer in $(RELEASE_OUTPUT)/windows-exe" >&2; exit 1; }; \
	if command -v cygpath >/dev/null 2>&1; then installer="$$(cygpath -w "$$installer")"; fi; \
	INSTALLER="$$installer" powershell -NoProfile -ExecutionPolicy Bypass -Command '$$p = Start-Process -FilePath $$env:INSTALLER -ArgumentList "/S" -Wait -PassThru; if ($$p.ExitCode -ne 0) { exit $$p.ExitCode }'; \
	WKHTMLTOPDF_BINARY='C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe' \
	WKHTMLTOIMAGE_BINARY='C:\Program Files\wkhtmltopdf\bin\wkhtmltoimage.exe' \
	$(PYTHON) tests/smoke/smoke.py

help:
	@echo "Common commands:"
	@echo "  make                       Build (use JOBS=8 or QT=4 when needed)"
	@echo "  make test                  Build and run smoke tests"
	@echo "  make install               Install to PREFIX=$(PREFIX); stages if /usr/local is not writable"
	@echo "  make install PREFIX=/path  Install to a writable prefix"
	@echo "  make clean                 Remove compiled objects; keep configuration"
	@echo "  make distclean             Remove BUILD_DIR=$(BUILD_DIR)"
	@echo ""
	@echo "Less common:"
	@echo "  make deps                  Install local build dependencies (QT=$(QT); add DRY_RUN=1 to preview)"
	@echo "  make stage                 Stage under STAGEDIR=$(STAGEDIR)"
	@echo "  make uninstall             Remove files from PREFIX=$(PREFIX)"
	@echo "  make smoke/check/e2e       Aliases for make test"
	@echo "  make release DRY_RUN=1     Preview release plan"
	@echo "  make release VERSION=0.13.0 PUSH=0"
	@echo "  make release BUMP=patch    Create release commit/tag and build packages"
	@echo "  make release BUILD=0       Tag only; skip package build"
	@echo "  make release-build         Build host release package into RELEASE_OUTPUT=$(RELEASE_OUTPUT)"
	@echo "  make release-test          Install and smoke-test the host release package"
	@echo ""
	@echo "Normal qmake targets are delegated to $(QMAKE_MAKEFILE) when it exists."
	@echo "Standard install variables: PREFIX/prefix, DESTDIR. INSTALLBASE and INSTALL_ROOT still work for qmake compatibility."
	@echo "Performance: JOBS controls parallelism; ccache is used automatically when available (set USE_CCACHE=0 to disable)."

%:
	+@if [ -f "$(BUILD_DIR)/$(QMAKE_MAKEFILE)" ]; then \
		exec $(MAKE) -C "$(BUILD_DIR)" $@; \
	elif [ -f "$(QMAKE_MAKEFILE)" ]; then \
		exec $(MAKE) -f "$(QMAKE_MAKEFILE)" $@; \
	else \
		echo "No qmake-generated $(QMAKE_MAKEFILE) found for target '$@'." >&2; \
		exit 2; \
	fi
