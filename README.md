# wkhtmltopdf

`wkhtmltopdf` converts HTML to PDF. `wkhtmltoimage` converts HTML to images. Inputs can be URLs, local files, or `-` for stdin/stdout.

## Quick use

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

## Shell completion

Install completion for your active shell only:

```sh
wkhtmltopdf --install-completion
wkhtmltoimage --install-completion
```

For package scripts or custom locations, generate a script with `--completion <bash|zsh|fish>`.

## Help and docs

- `wkhtmltopdf --help` / `wkhtmltopdf --extended-help`
- `wkhtmltoimage --help` / `wkhtmltoimage --extended-help`
- Website: <https://wkhtmltopdf.org>
- User docs: `docs/docs.md`, `docs/usage/wkhtmltopdf.txt`
- C API: `docs/libwkhtmltox/`

## Build

Official packages are built from <https://github.com/wkhtmltopdf/packaging>.

Local unpatched build (uses all available CPU threads by default, equivalent to `-j$(nproc)`):

```sh
make install-dev
make build
```

Manual qmake build:

```sh
mkdir -p build
cd build
qmake ../wkhtmltopdf.pro CONFIG+=silent
make -j"$(nproc)"
```

## License

LGPLv3+; see `LICENSE`.
