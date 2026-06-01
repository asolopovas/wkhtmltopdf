# Local build and release targets.

.DEFAULT_GOAL := all
.DELETE_ON_ERROR:

JOBS ?= $(shell nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
prefix ?= /usr/local
PREFIX ?= $(prefix)
DESTDIR ?=
DRY_RUN ?=
PYTHON ?= python3
SMOKE_TEST ?= tests/smoke/smoke.py
WKHTMLTOPDF_BINARY ?= /usr/bin/wkhtmltopdf
WKHTMLTOIMAGE_BINARY ?= /usr/bin/wkhtmltoimage

DOCKER ?= docker
DOCKERFILE ?= Dockerfile.build
DOCKER_IMAGE ?= asolopovas/wkhtmltox-linux-deb-build:20.04
DOCKER_BUILD_ARGS ?=
DOCKER_REBUILD ?= 0
DOCKER_PUSH ?= 1
DOCKER_DEV_FILE ?= Dockerfile.dev
DOCKER_DEV_IMAGE ?= asolopovas/wkhtmltox-dev:24.04
DOCKER_DEV_BUILD_ARGS ?=
DOCKER_DEV_REBUILD ?= $(DOCKER_REBUILD)
DOCKER_DEV_PUSH ?= $(DOCKER_PUSH)
DOCKER_SOCK ?= /var/run/docker.sock
PATCHED_QT_DIR ?= $(abspath tmp/builds/focal-amd64)
DOCKER_QMAKE ?= /tgt/qt/bin/qmake
WINDOWS_DOCKER_TARGET ?= mxe-cross-win64
WKHTMLTOX_PACKAGING_DIR ?= /tmp/wkhtmltopdf-packaging
WINDOWS_DOCKER_CLEAN ?= 0

RELEASE_VERSION ?= $(shell tr -d '[:space:]' < VERSION | sed 's/-.*//')
RELEASE_ITERATION ?= 1
RELEASE_OUTPUT ?= releases/$(RELEASE_VERSION)
RELEASE_BUILD_TARGETS ?= release-build-linux-deb release-build-windows-exe
RELEASE_TEST_TARGETS ?= release-test-linux-deb release-test-windows-exe
RELEASE_ARGS ?=
BUMP ?=
VERSION ?=
VERSION_OVERRIDE ?= $(VERSION)
BUILD ?= false
PUSH ?= true
UPLOAD ?= true

.PHONY: all build shadow-build docker-image docker-dev-image docker-shell test check smoke e2e
.PHONY: install stage clean distclean deps install-dev help
.PHONY: release release-patch release-minor release-major build-release
.PHONY: release-build release-build-all release-test release-test-all
.PHONY: release-build-linux-deb release-build-windows-exe release-build-windows-exe-docker release-build-windows-exe-msys2
.PHONY: release-test-linux-deb release-test-windows-exe

all: build

build shadow-build: release-build

docker-image:
	@if [ "$(DOCKER_REBUILD)" != "1" ] && $(DOCKER) image inspect "$(DOCKER_IMAGE)" >/dev/null 2>&1; then \
		exit 0; \
	fi; \
	if [ "$(DOCKER_REBUILD)" != "1" ] && $(DOCKER) pull "$(DOCKER_IMAGE)"; then \
		exit 0; \
	fi; \
	$(DOCKER) build -f "$(DOCKERFILE)" -t "$(DOCKER_IMAGE)" $(DOCKER_BUILD_ARGS) .; \
	if [ "$(DOCKER_PUSH)" = "1" ]; then $(DOCKER) push "$(DOCKER_IMAGE)"; fi

docker-dev-image:
	@if [ "$(DOCKER_DEV_REBUILD)" != "1" ] && $(DOCKER) image inspect "$(DOCKER_DEV_IMAGE)" >/dev/null 2>&1; then \
		exit 0; \
	fi; \
	if [ "$(DOCKER_DEV_REBUILD)" != "1" ] && $(DOCKER) pull "$(DOCKER_DEV_IMAGE)"; then \
		exit 0; \
	fi; \
	$(DOCKER) build -f "$(DOCKER_DEV_FILE)" -t "$(DOCKER_DEV_IMAGE)" $(DOCKER_DEV_BUILD_ARGS) .; \
	if [ "$(DOCKER_DEV_PUSH)" = "1" ]; then $(DOCKER) push "$(DOCKER_DEV_IMAGE)"; fi

docker-shell: docker-dev-image
	@mkdir -p "$(WKHTMLTOX_PACKAGING_DIR)"; \
	docker_socket_flags=; \
	if [ -S "$(DOCKER_SOCK)" ]; then \
		docker_socket_flags="-v $(DOCKER_SOCK):/var/run/docker.sock --group-add $$(stat -c '%g' "$(DOCKER_SOCK)")"; \
	fi; \
	$(DOCKER) run --rm -it \
		$$docker_socket_flags \
		--user "$$(id -u):$$(id -g)" \
		-e HOME=/tmp \
		-e HOST_UID="$$(id -u)" \
		-e HOST_GID="$$(id -g)" \
		-v "$(CURDIR):$(CURDIR)" \
		-v "$(WKHTMLTOX_PACKAGING_DIR):$(WKHTMLTOX_PACKAGING_DIR)" \
		-w "$(CURDIR)" \
		"$(DOCKER_DEV_IMAGE)" \
		bash

release-build-linux-deb:
	@if [ ! -x "$(PATCHED_QT_DIR)/qt/bin/qmake" ]; then \
		echo "ERROR: patched Qt qmake not found at $(PATCHED_QT_DIR)/qt/bin/qmake" >&2; \
		echo "Set PATCHED_QT_DIR=/path/to/patched-qt-build-root." >&2; \
		exit 2; \
	fi
	$(MAKE) docker-image
	$(DOCKER) run --rm \
		--user "$$(id -u):$$(id -g)" \
		-e HOME=/tmp \
		-e QMAKE="$(DOCKER_QMAKE)" \
		-e RELEASE_VERSION="$(RELEASE_VERSION)" \
		-e RELEASE_ITERATION="$(RELEASE_ITERATION)" \
		-e RELEASE_OUTPUT="$(RELEASE_OUTPUT)" \
		-e RELEASE_SERIES=linux \
		-e MAKE_JOBS="$(JOBS)" \
		-v "$(CURDIR):/src" \
		-v "$(PATCHED_QT_DIR):/tgt:ro" \
		-w /src \
		"$(DOCKER_IMAGE)" \
		scripts/build-linux-deb.sh

release-build-windows-exe: release-build-windows-exe-docker

release-build-windows-exe-docker: docker-dev-image
	@mkdir -p "$(WKHTMLTOX_PACKAGING_DIR)"; \
	docker_socket_flags=; \
	if [ -S "$(DOCKER_SOCK)" ]; then \
		docker_socket_flags="-v $(DOCKER_SOCK):/var/run/docker.sock --group-add $$(stat -c '%g' "$(DOCKER_SOCK)")"; \
	fi; \
	$(DOCKER) run --rm \
		$$docker_socket_flags \
		--user "$$(id -u):$$(id -g)" \
		-e HOME=/tmp \
		-e HOST_UID="$$(id -u)" \
		-e HOST_GID="$$(id -g)" \
		-e RELEASE_VERSION="$(RELEASE_VERSION)" \
		-e RELEASE_ITERATION="$(RELEASE_ITERATION)" \
		-e RELEASE_OUTPUT="$(RELEASE_OUTPUT)" \
		-e WINDOWS_DOCKER_TARGET="$(WINDOWS_DOCKER_TARGET)" \
		-e WINDOWS_DOCKER_CLEAN="$(WINDOWS_DOCKER_CLEAN)" \
		-e WKHTMLTOX_PACKAGING_DIR="$(WKHTMLTOX_PACKAGING_DIR)" \
		-v "$(CURDIR):$(CURDIR)" \
		-v "$(WKHTMLTOX_PACKAGING_DIR):$(WKHTMLTOX_PACKAGING_DIR)" \
		-w "$(CURDIR)" \
		"$(DOCKER_DEV_IMAGE)" \
		bash -ceu ' \
			if [ ! -x "$$WKHTMLTOX_PACKAGING_DIR/build" ]; then \
				rm -rf "$$WKHTMLTOX_PACKAGING_DIR"; \
				mkdir -p "$$(dirname -- "$$WKHTMLTOX_PACKAGING_DIR")"; \
				cp -a /opt/wkhtmltopdf-packaging "$$WKHTMLTOX_PACKAGING_DIR"; \
			fi; \
			build_args=(package-docker --iteration "$$RELEASE_ITERATION"); \
			if [ "$${WINDOWS_DOCKER_CLEAN:-0}" = "1" ]; then build_args+=(--clean); fi; \
			build_args+=("$$WINDOWS_DOCKER_TARGET" "$$PWD"); \
			( cd "$$WKHTMLTOX_PACKAGING_DIR" && python3 ./build "$${build_args[@]}" ); \
			archive="$$WKHTMLTOX_PACKAGING_DIR/targets/wkhtmltox-$$RELEASE_VERSION-$$RELEASE_ITERATION.$$WINDOWS_DOCKER_TARGET.7z"; \
			[ -f "$$archive" ] || { echo "ERROR: expected package archive not found: $$archive" >&2; exit 1; }; \
			stage_dir="$$PWD/package/wkhtmltox"; \
			extract_dir="$$(mktemp -d "$${TMPDIR:-/tmp}/wkhtmltox-windows-docker.XXXXXX")"; \
			trap '\''rm -rf "$$extract_dir"'\'' EXIT; \
			rm -rf "$$stage_dir" "$$RELEASE_OUTPUT/windows-exe"; \
			mkdir -p "$$stage_dir" "$$RELEASE_OUTPUT/windows-exe"; \
			7z x -y "-o$$extract_dir" "$$archive"; \
			[ -d "$$extract_dir/wkhtmltox" ] || { echo "ERROR: archive did not contain wkhtmltox/" >&2; exit 1; }; \
			cp -a "$$extract_dir/wkhtmltox/." "$$stage_dir/"; \
			cp LICENSE "$$stage_dir/LICENSE.txt"; \
			cp README.md "$$stage_dir/README.txt"; \
			for tool in wkhtmltopdf wkhtmltoimage; do \
				binary="$$stage_dir/bin/$$tool.exe"; \
				[ -f "$$binary" ] || { echo "ERROR: missing $$binary" >&2; exit 1; }; \
				binary_strings="$$(strings "$$binary")"; \
				grep -Fq "$$RELEASE_VERSION (with patched Qt)" <<<"$$binary_strings" || { echo "ERROR: $$tool.exe does not advertise $$RELEASE_VERSION (with patched Qt)" >&2; exit 1; }; \
				grep -Fq "full patched-Qt build" <<<"$$binary_strings" || { echo "ERROR: $$tool.exe does not contain the full patched-Qt build description" >&2; exit 1; }; \
			done; \
			installer="$$RELEASE_OUTPUT/windows-exe/wkhtmltox-$$RELEASE_VERSION-$$RELEASE_ITERATION.windows-$$WINDOWS_DOCKER_TARGET-installer.exe"; \
			makensis "-DVERSION=$$RELEASE_VERSION" "-DSOURCE_DIR=$$stage_dir" "-DOUT_FILE=$$PWD/$$installer" scripts/wkhtmltox.nsi; \
			( cd "$$RELEASE_OUTPUT" && find windows-exe -maxdepth 1 -type f -name "*.exe" -print | sort | xargs -r sha256sum > checksums-windows-exe.txt ); \
			[ -s "$$RELEASE_OUTPUT/checksums-windows-exe.txt" ] || { echo "ERROR: no Windows installers generated" >&2; exit 1; }; \
			echo "built $$PWD/$$installer" \
		'

release-build-windows-exe-msys2:
	RELEASE_VERSION="$(RELEASE_VERSION)" \
	RELEASE_OUTPUT="$(RELEASE_OUTPUT)" \
	MAKE_JOBS="$(JOBS)" \
	scripts/build-windows-msys2.sh

release-build: $(RELEASE_BUILD_TARGETS)

release-build-all: release-build-linux-deb release-build-windows-exe

release-test: $(RELEASE_TEST_TARGETS)

release-test-all: release-test-linux-deb release-test-windows-exe

release-test-linux-deb:
	@package="$$(ls -1 "$(RELEASE_OUTPUT)"/linux-deb/*.deb 2>/dev/null | head -n1)"; \
	[ -n "$$package" ] || { echo "release-test: no deb package in $(RELEASE_OUTPUT)/linux-deb" >&2; exit 1; }; \
	tests/deb/deb-loader.sh "$$package"

release-test-windows-exe:
	@installer="$$(ls -1 "$(RELEASE_OUTPUT)"/windows-exe/*.exe 2>/dev/null | head -n1)"; \
	[ -n "$$installer" ] || { echo "release-test: no exe installer in $(RELEASE_OUTPUT)/windows-exe" >&2; exit 1; }; \
	if command -v cygpath >/dev/null 2>&1; then installer="$$(cygpath -w "$$installer")"; else installer="$$installer"; fi; \
	INSTALLER="$$installer" powershell -NoProfile -ExecutionPolicy Bypass -Command '$$p = Start-Process -FilePath $$env:INSTALLER -ArgumentList "/S" -Wait -PassThru; if ($$p.ExitCode -ne 0) { exit $$p.ExitCode }'; \
	WKHTMLTOPDF_BINARY='C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe' \
	WKHTMLTOIMAGE_BINARY='C:\Program Files\wkhtmltopdf\bin\wkhtmltoimage.exe' \
	$(PYTHON) tests/smoke/smoke.py

test check smoke e2e: build release-test-linux-deb
	WKHTMLTOPDF_BINARY="$(WKHTMLTOPDF_BINARY)" \
	WKHTMLTOIMAGE_BINARY="$(WKHTMLTOIMAGE_BINARY)" \
	$(PYTHON) "$(SMOKE_TEST)"

release:
	@./scripts/release.sh \
		$(if $(BUMP),--bump $(BUMP)) \
		$(if $(VERSION_OVERRIDE),--version $(VERSION_OVERRIDE)) \
		$(if $(filter 0 false no,$(BUILD)),--no-build,--build) \
		$(if $(filter 0 false no,$(PUSH)),--no-push) \
		$(if $(filter 0 false no,$(UPLOAD)),--no-upload,--upload) \
		$(if $(filter 1 true yes,$(DRY_RUN)),--dry-run) \
		$(RELEASE_ARGS)

build-release:
	$(MAKE) build
	$(MAKE) release BUILD=false

release-patch release-minor release-major:
	$(MAKE) release BUMP=$(patsubst release-%,%,$@) $(if $(RELEASE_ARGS),RELEASE_ARGS='$(RELEASE_ARGS)',)

install: build
	@package="$$(ls -1 "$(RELEASE_OUTPUT)"/linux-deb/*.deb 2>/dev/null | head -n1)"; \
	[ -n "$$package" ] || { echo "install: no deb package in $(RELEASE_OUTPUT)/linux-deb" >&2; exit 1; }; \
	if [ -n "$(DESTDIR)" ]; then \
		mkdir -p "$(DESTDIR)"; \
		cp "$$package" "$(DESTDIR)/"; \
	else \
		sudo apt-get install -y "$$package"; \
	fi

stage: DESTDIR ?= $(abspath releases/stage)
stage: install

deps install-dev:
	./scripts/install-dev-deps.sh $(if $(DRY_RUN),--dry-run,)

clean:
	@rm -rf "$(RELEASE_OUTPUT)/linux-deb" "$(RELEASE_OUTPUT)/checksums-linux-deb.txt"

distclean:
	@rm -rf build build-* package "$(RELEASE_OUTPUT)"

help:
	@echo "Common commands:"
	@echo "  make                       Build Linux and Windows packages inside Docker"
	@echo "  make test                  Build and run Linux package checks"
	@echo "  make install               Install built .deb with apt"
	@echo "  make stage DESTDIR=/path   Copy built .deb into DESTDIR"
	@echo "  make clean                 Remove Linux .deb artifacts for RELEASE_OUTPUT=$(RELEASE_OUTPUT)"
	@echo "  make distclean             Remove local build/package output"
	@echo "  make docker-shell          Open the dev image with this checkout mounted at the same host path"
	@echo ""
	@echo "Release:"
	@echo "  make release DRY_RUN=1     Preview release/tag/upload plan without building"
	@echo "  make release VERSION=0.13.0 PUSH=0"
	@echo "  make release BUMP=patch    Create release commit/tag and upload existing artifacts"
	@echo "  make build-release         Build packages, then create/push/upload the release"
	@echo "  make release-build         Build Linux .deb and Windows installer"
	@echo "  make release-build-windows-exe-docker  Build Windows installer via Docker/MXE"
	@echo "  make release-build-windows-exe-msys2   Build Windows installer on an MSYS2 host"
	@echo ""
	@echo "Docker build input: PATCHED_QT_DIR=$(PATCHED_QT_DIR)"
	@echo "Docker image knobs: DOCKER_IMAGE=$(DOCKER_IMAGE), DOCKER_REBUILD=$(DOCKER_REBUILD), DOCKER_PUSH=$(DOCKER_PUSH)"
	@echo "Dev image knobs: DOCKER_DEV_IMAGE=$(DOCKER_DEV_IMAGE), DOCKER_DEV_REBUILD=$(DOCKER_DEV_REBUILD), DOCKER_DEV_PUSH=$(DOCKER_DEV_PUSH)"
	@echo "Windows Docker knobs: WINDOWS_DOCKER_TARGET=$(WINDOWS_DOCKER_TARGET), WKHTMLTOX_PACKAGING_DIR=$(WKHTMLTOX_PACKAGING_DIR), WINDOWS_DOCKER_CLEAN=$(WINDOWS_DOCKER_CLEAN)"
