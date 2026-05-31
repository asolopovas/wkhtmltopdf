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

.PHONY: all install clean distclean help install-dev configure build shadow-build

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

help:
	@echo "Developer targets:"
	@echo "  make install-dev           Install local build dependencies (default: QT=5)"
	@echo "  make install-dev QT=4      Install legacy Qt 4 build dependencies"
	@echo "  make install-dev DRY_RUN=1 Print the package install command only"
	@echo "  make build                 Configure/build in BUILD_DIR=$(BUILD_DIR)"
	@echo ""
	@echo "Normal qmake targets are delegated to $(QMAKE_MAKEFILE) when it exists."

%:
	+@if [ -f "$(QMAKE_MAKEFILE)" ]; then \
		exec $(MAKE) -f "$(QMAKE_MAKEFILE)" $@; \
	else \
		echo "No qmake-generated $(QMAKE_MAKEFILE) found for target '$@'." >&2; \
		exit 2; \
	fi
