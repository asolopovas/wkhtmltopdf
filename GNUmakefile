# Developer convenience targets.
#
# qmake generates a file named Makefile at the repository root. GNU make
# prefers GNUmakefile when present, so keep this file as a thin wrapper and
# delegate normal build/install targets to qmake's generated Makefile.

.DEFAULT_GOAL := all

QMAKE_MAKEFILE ?= Makefile
BUILD_DIR ?= build
QMAKE ?= $(shell command -v qmake-qt4 2>/dev/null || command -v qmake 2>/dev/null)
QMAKE_CONFIG ?= CONFIG+=silent
QT ?= 5
DRY_RUN ?=
PYTHON ?= python3
PACKAGING_REPO ?= https://github.com/wkhtmltopdf/packaging.git
PACKAGING_DIR ?= ../packaging
RELEASE_VERSION ?= $(shell tr -d '[:space:]' < VERSION | sed 's/-.*//')
RELEASE_ITERATION ?= 1
RELEASE_OUTPUT ?= releases/$(RELEASE_VERSION)
RELEASE_LINUX_TARGET ?= bullseye-amd64
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
VERSION_OVERRIDE ?=
PUSH ?= true
UPLOAD ?= false


.PHONY: all install clean distclean help install-dev configure build shadow-build release release-patch release-minor release-major release-build release-build-all release-test release-test-all release-build-linux-deb release-build-windows-exe release-test-linux-deb release-test-windows-exe ensure-packaging

all install clean distclean:
	+@if [ -f "$(QMAKE_MAKEFILE)" ]; then \
		exec $(MAKE) -f "$(QMAKE_MAKEFILE)" $@; \
	else \
		echo "No qmake-generated $(QMAKE_MAKEFILE) found." >&2; \
		echo "Run qmake first, preferably from a shadow build directory:" >&2; \
		echo "  mkdir -p build && cd build && qmake ../wkhtmltopdf.pro CONFIG+=silent && make" >&2; \
		exit 2; \
	fi

install-dev:
	./scripts/install-dev-deps.sh --qt "$(QT)" $(if $(DRY_RUN),--dry-run,)

configure:
	@if [ -z "$(QMAKE)" ]; then \
		echo "qmake not found. Run 'make install-dev' first, or set QMAKE=/path/to/qmake." >&2; \
		exit 127; \
	fi
	mkdir -p "$(BUILD_DIR)"
	cd "$(BUILD_DIR)" && "$(QMAKE)" ../wkhtmltopdf.pro $(QMAKE_CONFIG)

build shadow-build: configure
	$(MAKE) -C "$(BUILD_DIR)"

release:
	@args="$(RELEASE_ARGS)"; \
	if [ -n "$(BUMP)" ]; then args="--bump $(BUMP) $$args"; fi; \
	if [ -n "$(VERSION_OVERRIDE)" ]; then args="--version $(VERSION_OVERRIDE) $$args"; fi; \
	if [ "$(PUSH)" != "true" ]; then args="--no-push $$args"; fi; \
	if [ "$(UPLOAD)" = "true" ]; then args="--upload $$args"; fi; \
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
	@echo "Developer targets:"
	@echo "  make install-dev           Install local build dependencies (default: QT=5)"
	@echo "  make install-dev QT=4      Install legacy Qt 4 build dependencies"
	@echo "  make install-dev DRY_RUN=1 Print the package install command only"
	@echo "  make build                 Configure/build in BUILD_DIR=$(BUILD_DIR)"
	@echo "  make release VERSION_OVERRIDE=0.13.0"
	@echo "  make release BUMP=patch    Create release commit/tag and build packages"
	@echo "  make release-build         Build host release package into RELEASE_OUTPUT=$(RELEASE_OUTPUT)"
	@echo "  make release-test          Install and smoke-test the host release package"
	@echo "  make release-build-all     Build deb+exe when the host can support both"
	@echo ""
	@echo "Normal qmake targets are delegated to $(QMAKE_MAKEFILE) when it exists."

%:
	+@if [ -f "$(QMAKE_MAKEFILE)" ]; then \
		exec $(MAKE) -f "$(QMAKE_MAKEFILE)" $@; \
	else \
		echo "No qmake-generated $(QMAKE_MAKEFILE) found for target '$@'." >&2; \
		exit 2; \
	fi
