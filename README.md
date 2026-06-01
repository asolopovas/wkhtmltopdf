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

Local unpatched build:

```sh
make deps      # once, when build dependencies are missing
make           # configure + parallel build
make test      # smoke test
```

Install with standard Make variables:

```sh
make install PREFIX="$HOME/.local"
sudo make install PREFIX=/usr/local
make install DESTDIR="$PWD/package" PREFIX=/usr
```

Useful cleanup:

```sh
make clean      # remove objects, keep configuration
make distclean  # remove the build directory
```

`make` uses all available CPU threads by default. Override with `JOBS=8`. If `ccache` is installed, the wrapper uses it automatically.

Release helpers use the same small command surface:

```sh
make release DRY_RUN=1
make release VERSION=0.13.0 PUSH=0
make release BUMP=patch
```

## License

LGPLv3+; see `LICENSE`.
