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

For engine limits, security guidance, AVIF support, and alternatives, see [`docs/status.md`](docs/status.md).

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

Linux release packages in this fork use system Qt 5 so Qt image plugins such as AVIF can be bundled.
The legacy patched-Qt packaging flow remains available for features that require wkhtmltopdf's Qt patches, but patched Qt 4 cannot use Qt 5 image plugins.

```sh
make           # install/check deps, then configure + build
make test      # smoke test the development build
```

Install and clean:

```sh
make install PREFIX="$HOME/.local"
sudo make install PREFIX=/usr/local
make install DESTDIR="$PWD/package" PREFIX=/usr
make clean
make distclean
```

Useful development knobs: `JOBS=8`, `QT=4`, `USE_CCACHE=0`, `AUTO_DEPS=0`.

Release helpers:

```sh
make release DRY_RUN=1
make release VERSION=0.13.0 PUSH=0
make release BUMP=patch
```

## License

LGPLv3+; see `LICENSE`.
