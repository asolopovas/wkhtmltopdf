# wkhtmltopdf and wkhtmltoimage

`wkhtmltopdf` and `wkhtmltoimage` render HTML to PDF or images with Qt WebKit. They run headlessly and do not require a display server.

## Documentation

- User docs: <https://wkhtmltopdf.org>
- CLI manual: `docs/usage/wkhtmltopdf.txt` or `wkhtmltopdf -H`
- C API docs: `docs/libwkhtmltox/`
- Project status and security notes: `docs/status.md`

## Security

Do not render untrusted HTML. If you must, isolate the process and restrict filesystem/network access; see `docs/apparmor.md`.

## Build and packaging

Build and packaging live in <https://github.com/wkhtmltopdf/packaging>.

For local unpatched builds on Debian/Ubuntu, install development packages with:

```bash
make install-dev
```

Then use a shadow build to keep generated files out of the source tree:

```bash
make build
```
