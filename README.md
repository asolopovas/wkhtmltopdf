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

AVIF images are handled through Qt image plugins. Install a Qt AVIF plugin
(for example `qt5-avif-image-plugin` on Ubuntu/Debian) and keep it on Qt's
plugin path; wkhtmltopdf automatically allows the `avif` image format for
QtWebKit when the plugin is present and no custom image-format whitelist is set.

For controlled templates, keep the fast Qt WebKit path by writing CSS with
fallbacks before modern layout rules:

```css
.cards { display: table; width: 100%; }      /* wkhtmltopdf fallback */
.card { display: table-cell; width: 33.33%; }
@supports (display: grid) {
  .cards { display: grid; grid-template-columns: repeat(3, 1fr); }
  .card { display: block; width: auto; }
}
```

Use a Chromium/Puppeteer-style backend only for inputs that truly require
uncontrolled modern browser behavior or JavaScript-heavy rendering.

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
make test
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
