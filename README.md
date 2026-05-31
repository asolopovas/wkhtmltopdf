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

## Maintenance

Use concise, checked-in knowledge. Review, test, and document AI-assisted changes like any other change.
