# wkhtmltopdf

`wkhtmltopdf` converts HTML to PDF. `wkhtmltoimage` converts HTML to images. Inputs can be URLs, local files, or `-` for stdin/stdout.

## Use

```sh
wkhtmltopdf https://example.com page.pdf
wkhtmltopdf report.html report.pdf
cat report.html | wkhtmltopdf - - > report.pdf

wkhtmltoimage https://example.com page.png
wkhtmltoimage --width 1280 --format jpg page.html page.jpg
```

Common PDF options:

```sh
wkhtmltopdf --page-size Letter --orientation Landscape --margin-top 10mm page.html page.pdf
wkhtmltopdf cover cover.html toc chapter1.html chapter2.html book.pdf
```

For engine limits, security guidance, and alternatives, see [`docs/status.md`](docs/status.md).

## Completion

```sh
wkhtmltopdf --install-completion
wkhtmltoimage --install-completion
```

Package scripts can use `--completion <bash|zsh|fish>`.

## Docs

- CLI: `wkhtmltopdf --help`, `wkhtmltopdf --extended-help`, `docs/usage/wkhtmltopdf.txt`
- Image CLI: `wkhtmltoimage --help`, `wkhtmltoimage --extended-help`
- C API: `docs/libwkhtmltox/`
- Index: `docs/docs.md`
- Website: <https://wkhtmltopdf.org>

## Build

Release packages in this fork are full-functionality patched-Qt builds. `wkhtmltopdf --version` must print `(with patched Qt)`, and `wkhtmltopdf --help` must not show a `Reduced Functionality` section.

During `.deb` installation, stale `/usr/local/bin/wkhtmltopdf`, `/usr/local/bin/wkhtmltoimage`, and `/usr/local/lib/libwkhtmltox.so*` files are moved aside because they can shadow the packaged `/usr/bin` wrappers and make an old unpatched binary appear to be the new release.

Linux `.deb` packages recommend ImageMagick for optional AVIF image decoding. If using an unpacked/custom build, install ImageMagick or set `WKHTMLTOX_AVIF_CONVERTER=/path/to/converter` to a command that converts `input.avif output.png`.

```sh
make           # build the Linux .deb inside Docker
make test      # build and run Linux package checks
```

Install and clean:

```sh
make install PREFIX="$HOME/.local"
make install PREFIX=/usr/local       # uses sudo when /usr/local is not writable
make stage PREFIX=/usr/local         # create a staged tree without installing
make install DESTDIR="$PWD/package" PREFIX=/usr
make clean
make distclean
```

Useful build knobs: `JOBS=8`, `PATCHED_QT_DIR=/path/to/patched-qt-build-root`, `DOCKER_IMAGE=registry/name:tag`.

Release helpers:

```sh
make release DRY_RUN=1
make release VERSION=0.13.0 PUSH=0
make release BUMP=patch  # build Linux .deb + Windows installer, then upload
```

## License

LGPLv3+; see `LICENSE`.
