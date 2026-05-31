.DEFAULT_GOAL := all

CC ?= cc

PREFIX ?= ..
INCLUDEDIR ?= $(PREFIX)/include
LIBDIR ?= $(PREFIX)/bin

CPPFLAGS += -I$(INCLUDEDIR)
CFLAGS += -Wall -Wextra -ansi -pedantic -ggdb
LDFLAGS += -L$(LIBDIR)
LDLIBS += -lwkhtmltox

EXAMPLES := pdf_c_api image_c_api
RUN_LIBRARY_PATH := $(abspath $(LIBDIR))$(if $(LD_LIBRARY_PATH),:$(LD_LIBRARY_PATH))

.PHONY: all clean help run run-pdf run-image runimage

all: $(EXAMPLES)

$(EXAMPLES): %: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< $(LDFLAGS) $(LDLIBS) -o $@

run: run-pdf

run-pdf: pdf_c_api
	LD_LIBRARY_PATH="$(RUN_LIBRARY_PATH)" ./pdf_c_api

run-image runimage: image_c_api
	LD_LIBRARY_PATH="$(RUN_LIBRARY_PATH)" ./image_c_api

clean:
	$(RM) $(EXAMPLES)

help:
	@printf '%s\n' \
		'Targets:' \
		'  all        Build all C API examples (default)' \
		'  run        Build and run the PDF example' \
		'  run-pdf    Build and run the PDF example' \
		'  run-image  Build and run the image example' \
		'  clean      Remove built example binaries' \
		'' \
		'Variables:' \
		'  PREFIX     Base directory for include/bin paths (default: ..)' \
		'  INCLUDEDIR Header directory (default: $$(PREFIX)/include)' \
		'  LIBDIR     Library directory (default: $$(PREFIX)/bin)'
