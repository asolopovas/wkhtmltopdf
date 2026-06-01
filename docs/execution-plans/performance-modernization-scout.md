# Performance and modernization scout plan

## Goal

Identify concrete update opportunities in the library and implement the safest local performance improvements without changing wkhtmltopdf output behavior.

## Scope

- [x] Scout dependency/API modernization opportunities in code, build workflows, and docs.
- [x] Implement Qt4-compatible, low-risk performance cleanups in isolated hot paths.
- [x] Defer renderer/backend modernization decisions that require a Qt4 vs Qt5+ support decision.
- [x] Implement remaining low-risk PDF link/form location caching behind the patched-Qt feature guard.
- [x] Remove unused docs-site Foundation/jQuery runtime scripts from the default layout.

## Acceptance criteria

- [x] Page-size string conversion avoids rebuilding a map on every call.
- [x] Command-line option sorting avoids per-comparison regular-expression allocation.
- [x] Simple URL guessing avoids regular expressions for host/schema checks.
- [x] Large file copies avoid loading the entire source into memory.
- [x] Multipart file assembly avoids an extra whole-file `readAll()` allocation.
- [x] Cropped image background fill only touches the render target area.
- [x] PDF link/form page bucketing reuses `elementLocation()` rectangles instead of recomputing them while spooling.
- [x] Repeated internal PDF link target resolution caches positive and negative DOM lookups.
- [x] The static docs layout no longer loads unused CDN jQuery/Foundation scripts.
- [x] Changes remain Qt4-compatible and pass the closest local checks available.

## Update opportunities found

- Qt/WebKit modernization is blocked by the current patched Qt 4.8.7 support lane; decide whether Qt4 remains official before larger API churn.
- Align duplicate release/official workflows or explicitly document the legacy Qt4 packaging path.
- Incrementally replace deprecated Qt APIs (`QRegExp`, `foreach`, string-based `SIGNAL`/`SLOT`) after the Qt support policy is clear.
- Improve PDF link fixture coverage under a patched-Qt build where PDF link annotations are enabled.
- Review broader generated docs assets separately before touching `docs/libwkhtmltox/` output.

## Validation log

- [x] `make -C build -j2` (after first cleanup pass)
- [x] `make -C build -j2` (after PDF cache and URL parser cleanup pass)
- [x] `WKHTMLTOPDF_BINARY=$PWD/build/bin/wkhtmltopdf WKHTMLTOIMAGE_BINARY=$PWD/build/bin/wkhtmltoimage python3 tests/smoke/smoke.py`
- [x] `tmp=$(mktemp -d); build/bin/wkhtmltopdf --quiet --page-size Letter tests/fixtures/html/simple.html "$tmp/letter.pdf"; test -s "$tmp/letter.pdf"; rm -rf "$tmp"`
- [x] `build/bin/wkhtmltopdf --extended-help >/tmp/wkhtmltopdf.extended-help.txt`
- [x] `build/bin/wkhtmltopdf --completion bash >/tmp/wkhtmltopdf.bash-completion.txt`
- [x] `build/bin/wkhtmltopdf --completion zsh >/tmp/wkhtmltopdf.zsh-completion.txt`
- [x] `build/bin/wkhtmltopdf --completion fish >/tmp/wkhtmltopdf.fish-completion.txt`
- [x] `rg -n "jquery-2.1.0|foundation.min.js|foundation\\(" docs/_layouts/default.html -S` (no matches)
- [x] Reviewer subagent static review of uncommitted diff, including patched-Qt guarded PDF changes.
- [x] `git diff --check`

## Progress notes

- 2026-06-01: Created plan after repository scout. Starting with isolated Qt4-compatible performance cleanups.
- 2026-06-01: Implemented the scoped cleanups and validated build, smoke tests, help/completion generation, and whitespace checks.
- 2026-06-01: Continued with remaining low-risk items: cached PDF link target and element rectangle lookups, replaced simple URL regex checks with direct string scans, chunked multipart file appends, and removed unused docs-site jQuery/Foundation runtime scripts.
