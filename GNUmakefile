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
PATCHED_QT_DIR ?= $(abspath tmp/builds/focal-amd64)
DOCKER_QMAKE ?= /tgt/qt/bin/qmake

RELEASE_VERSION ?= $(shell tr -d '[:space:]' < VERSION | sed 's/-.*//')
RELEASE_ITERATION ?= 1
RELEASE_OUTPUT ?= releases/$(RELEASE_VERSION)
RELEASE_BUILD_TARGETS ?= release-build-linux-deb release-build-windows-exe
RELEASE_TEST_TARGETS ?= release-test-linux-deb release-test-windows-exe
RELEASE_ARGS ?=
BUMP ?=
VERSION ?=
VERSION_OVERRIDE ?= $(VERSION)
BUILD ?= true
PUSH ?= true
UPLOAD ?= true

.PHONY: all build shadow-build docker-image test check smoke e2e
.PHONY: install stage clean distclean deps install-dev help
.PHONY: release release-patch release-minor release-major
.PHONY: release-build release-build-all release-test release-test-all
.PHONY: release-build-linux-deb release-build-windows-exe
.PHONY: release-test-linux-deb release-test-windows-exe

all: build

build shadow-build: release-build-linux-deb

docker-image:
	$(DOCKER) pull "$(DOCKER_IMAGE)" || { \
		$(DOCKER) build -f "$(DOCKERFILE)" -t "$(DOCKER_IMAGE)" $(DOCKER_BUILD_ARGS) . && \
		$(DOCKER) push "$(DOCKER_IMAGE)"; \
	}

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

release-build-windows-exe:
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
		$(if $(filter 0 false no,$(BUILD)),--no-build) \
		$(if $(filter 0 false no,$(PUSH)),--no-push) \
		$(if $(filter 1 true yes,$(UPLOAD)),--upload) \
		$(if $(filter 1 true yes,$(DRY_RUN)),--dry-run) \
		$(RELEASE_ARGS)

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
	@echo "  make                       Build the Linux .deb inside Docker"
	@echo "  make test                  Build and run Linux package checks"
	@echo "  make install               Install built .deb with apt"
	@echo "  make stage DESTDIR=/path   Copy built .deb into DESTDIR"
	@echo "  make clean                 Remove Linux .deb artifacts for RELEASE_OUTPUT=$(RELEASE_OUTPUT)"
	@echo "  make distclean             Remove local build/package output"
	@echo ""
	@echo "Release:"
	@echo "  make release DRY_RUN=1     Preview local release plan"
	@echo "  make release VERSION=0.13.0 PUSH=0"
	@echo "  make release BUMP=patch    Create release commit/tag, build packages, and upload"
	@echo "  make release-build         Build Linux .deb and Windows installer"
	@echo ""
	@echo "Docker build input: PATCHED_QT_DIR=$(PATCHED_QT_DIR)"
