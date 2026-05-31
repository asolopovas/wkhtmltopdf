# wkhtmltopdf

`wkhtmltopdf` and `wkhtmltoimage` convert HTML to PDF or images with Qt WebKit. They run headlessly and include a C library.

## Docs

- Website: <https://wkhtmltopdf.org>
- Docs index: `docs/docs.md`
- CLI: `docs/usage/wkhtmltopdf.txt`, `wkhtmltopdf -H`, `wkhtmltoimage -H`
- C API: `docs/libwkhtmltox/`
- Maintainers: `docs/source-guide.md`, `docs/settings.md`
- Status and security: `docs/status.md`, `docs/apparmor.md`

## Build

Official packages live in <https://github.com/wkhtmltopdf/packaging>.

Local unpatched build:

```sh
make install-dev
make build
```

## Release

Start the maintained line at `0.13.0`, then bump from there:

```sh
make release VERSION_OVERRIDE=0.13.0
make release BUMP=patch
```

Release tags trigger `.github/workflows/release.yml`, which builds and uploads Linux `.deb` and Windows `.exe` packages.

## Maintenance

Use concise, checked-in knowledge. Review, test, and document AI-assisted changes like any other change.
