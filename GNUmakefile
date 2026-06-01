# Developer convenience targets.
#
# qmake generates a file named Makefile at the repository root. GNU make
# prefers GNUmakefile when present, so keep this file as a thin wrapper and
# delegate normal build/install targets to qmake's generated Makefile.

.DEFAULT_GOAL := all
.DELETE_ON_ERROR:

# Common user knobs. Keep these standard and memorable: make JOBS=8,
# make PREFIX=/path install, make DESTDIR=/tmp/pkg install.
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
INSTALL_ROOT ?=
DESTDIR ?= $(INSTALL_ROOT)
STAGEDIR ?= $(abspath $(BUILD_DIR)/stage)
PROJECT_FILE ?= $(abspath wkhtmltopdf.pro)
DRY_RUN ?=
PYTHON ?= python3
SMOKE_TEST ?= tests/smoke/smoke.py
AUTO_DEPS ?= 1
DEPS_STAMP ?= $(BUILD_DIR)/.deps.qt$(QT).stamp
WKHTMLTOPDF_BINARY ?= $(abspath $(BUILD_DIR)/bin/wkhtmltopdf)
WKHTMLTOIMAGE_BINARY ?= $(abspath $(BUILD_DIR)/bin/wkhtmltoimage)
# Release/package knobs.
PACKAGING_REPO ?= https://github.com/wkhtmltopdf/packaging.git
PACKAGING_DIR ?= ../packaging
RELEASE_VERSION ?= $(shell tr -d '[:space:]' < VERSION | sed 's/-.*//')
RELEASE_ITERATION ?= 1
RELEASE_OUTPUT ?= releases/$(RELEASE_VERSION)
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


.PHONY: all build configure test check smoke e2e
.PHONY: install stage uninstall clean distclean deps install-dev ensure-deps help
.PHONY: release release-patch release-minor release-major
.PHONY: release-build release-build-all release-test release-test-all
.PHONY: release-build-linux-deb release-build-windows-exe
.PHONY: release-test-linux-deb release-test-windows-exe ensure-packaging

all: build

install: build
	+@destdir="$(DESTDIR)"; \
	prefix="$(INSTALLBASE)"; \
	install_make="$(MAKE) -C $(BUILD_DIR) install"; \
	ldconfig_cmd=""; \
	if [ -z "$$destdir" ]; then \
		probe="$$prefix"; \
		while [ ! -e "$$probe" ] && [ "$$probe" != "/" ]; do probe="$$(dirname -- "$$probe")"; done; \
		if [ "$$(id -u)" != "0" ] && [ ! -w "$$probe" ]; then \
			if command -v sudo >/dev/null 2>&1; then \
				echo "PREFIX=$$prefix is not writable; using sudo for install"; \
				install_make="sudo $(MAKE) -C $(BUILD_DIR) install"; \
			else \
				echo "ERROR: PREFIX=$$prefix is not writable and sudo was not found." >&2; \
				exit 13; \
			fi; \
		fi; \
		if command -v ldconfig >/dev/null 2>&1 && { [ "$(INSTALLBASE)" = "/usr" ] || [ "$(INSTALLBASE)" = "/usr/local" ]; }; then \
			if [ "$$(id -u)" = "0" ]; then ldconfig_cmd="ldconfig"; \
			elif command -v sudo >/dev/null 2>&1; then ldconfig_cmd="sudo ldconfig"; fi; \
		fi; \
	fi; \
	$$install_make INSTALL_ROOT="$$destdir" || exit $$?; \
	if [ -n "$$ldconfig_cmd" ]; then $$ldconfig_cmd; fi

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
	if [ ! -d "$$build_dir" ]; then \
		echo "Nothing to distclean."; \
	elif [ -f "$$build_dir/.configure.args" ] || [ "$$build_dir" = "$(CURDIR)/build" ]; then \
		rm -rf "$$build_dir"; \
	else \
		echo "Refusing to remove BUILD_DIR=$$build_dir; it was not configured by this wrapper." >&2; \
		exit 2; \
	fi

deps install-dev:
	./scripts/install-dev-deps.sh --qt "$(QT)" $(if $(DRY_RUN),--dry-run,)

ensure-deps:
	@if [ "$(AUTO_DEPS)" = "0" ] || [ "$(AUTO_DEPS)" = "false" ] || [ "$(AUTO_DEPS)" = "no" ]; then \
		echo "ensure-deps: skipped because AUTO_DEPS=$(AUTO_DEPS)"; \
		exit 0; \
	fi; \
	mkdir -p "$(BUILD_DIR)"; \
	stamp="$(DEPS_STAMP)"; \
	if [ ! -f "$$stamp" ] || [ "scripts/install-dev-deps.sh" -nt "$$stamp" ]; then \
		./scripts/install-dev-deps.sh --qt "$(QT)" $(if $(DRY_RUN),--dry-run,) || exit $$?; \
		if [ -z "$(DRY_RUN)" ]; then touch "$$stamp"; fi; \
	else \
		echo "ensure-deps: up to date"; \
	fi

configure: ensure-deps
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
	@./scripts/release.sh \
		$(if $(BUMP),--bump $(BUMP)) \
		$(if $(VERSION_OVERRIDE),--version $(VERSION_OVERRIDE)) \
		$(if $(filter 0 false no,$(BUILD)),--no-build) \
		$(if $(filter 0 false no,$(PUSH)),--no-push) \
		$(if $(filter 1 true yes,$(UPLOAD)),--upload) \
		$(if $(filter 1 true yes,$(DRY_RUN)),--dry-run) \
		$(RELEASE_ARGS)

release-patch release-minor release-major:
	$(MAKE) release BUMP=$(patsubst release-%,%,$@) $(if $(RELEASE_ARGS),RELEASE_ARGS='$(RELEASE_ARGS)',)

release-build: $(RELEASE_BUILD_TARGETS)

release-build-all: release-build-linux-deb release-build-windows-exe

release-test: $(RELEASE_TEST_TARGETS)

release-test-all: release-test-linux-deb release-test-windows-exe

ensure-packaging:
	@if [ ! -x "$(PACKAGING_DIR)/build" ]; then \
		echo "Cloning packaging into $(PACKAGING_DIR)"; \
		git clone --depth 1 "$(PACKAGING_REPO)" "$(PACKAGING_DIR)"; \
	fi

release-build-linux-deb:
	RELEASE_VERSION="$(RELEASE_VERSION)" \
	RELEASE_ITERATION="$(RELEASE_ITERATION)" \
	RELEASE_OUTPUT="$(RELEASE_OUTPUT)" \
	RELEASE_SERIES=linux \
	MAKE_JOBS="$(JOBS)" \
	scripts/build-linux-deb.sh

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
	system_ld_library_path="/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:/lib:/usr/lib"; \
	sudo env LD_LIBRARY_PATH="$$system_ld_library_path" apt-get update; \
	sudo env LD_LIBRARY_PATH="$$system_ld_library_path" apt-get install -y --no-install-recommends binutils file libc-bin; \
	tests/deb/deb-loader.sh "$$package"; \
	WKHTMLTOPDF_BINARY=/usr/bin/wkhtmltopdf \
	WKHTMLTOIMAGE_BINARY=/usr/bin/wkhtmltoimage \
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
	@echo "  make                       Install/check deps, then build system-Qt development binaries"
	@echo "  make test                  Build and run smoke tests"
	@echo "  make install               Install to PREFIX=$(PREFIX); uses sudo when necessary"
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
	@echo "Dependencies: make build/install runs make deps once by default (set AUTO_DEPS=0 to skip)."

%:
	+@if [ -f "$(BUILD_DIR)/$(QMAKE_MAKEFILE)" ]; then \
		exec $(MAKE) -C "$(BUILD_DIR)" $@; \
	elif [ -f "$(QMAKE_MAKEFILE)" ]; then \
		exec $(MAKE) -f "$(QMAKE_MAKEFILE)" $@; \
	else \
		echo "No qmake-generated $(QMAKE_MAKEFILE) found for target '$@'." >&2; \
		exit 2; \
	fi
