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

Official packages are built from <https://github.com/wkhtmltopdf/packaging>.

```sh
make deps      # once, if dependencies are missing
make           # configure + parallel build
make test      # smoke test
```

Install and clean:

```sh
make install PREFIX="$HOME/.local"
sudo make install PREFIX=/usr/local
make install DESTDIR="$PWD/package" PREFIX=/usr
make clean
make distclean
```

Useful knobs: `JOBS=8`, `QT=4`, `USE_CCACHE=0`.

Release helpers:

```sh
make release DRY_RUN=1
make release VERSION=0.13.0 PUSH=0
make release BUMP=patch
```

## License

LGPLv3+; see `LICENSE`.
