# wkhtmltopdf

`wkhtmltopdf` and `wkhtmltoimage` convert HTML to PDF or images with Qt WebKit.
They run headlessly and do not require a display server.

## Documentation

- Project website: <https://wkhtmltopdf.org>
- CLI reference: `docs/usage/wkhtmltopdf.txt`, `wkhtmltopdf -H`, or `wkhtmltoimage -H`
- C API reference: `docs/libwkhtmltox/`
- Source guide: `docs/source-guide.md`
- Settings guide: `docs/settings.md`
- Project status: `docs/status.md`

## Security

Do not render untrusted HTML. If you must, isolate the process and restrict
filesystem and network access. Start with `docs/status.md` and `docs/apparmor.md`.

## Building

Official package builds live in <https://github.com/wkhtmltopdf/packaging>.

For local unpatched builds on supported systems:

```sh
make install-dev
make build
```

## Maintenance note

I plan to make incremental updates to this project with help from AI tools.
Changes should still be reviewed, tested, and documented. The goal is to make
wkhtmltopdf easier to maintain, easier to use, and better documented.
