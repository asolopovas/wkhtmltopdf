# Pull-request ideas implementation plan

## Goal

Implement the remaining high-value, lower-risk ideas from upstream pull requests and fork commits while preserving wkhtmltopdf behavior, keeping each feature isolated, and adding test coverage for every implemented change.

## Scope and ordering

- [x] Feature 1: cache/reuse HTML header and footer content and add explicit header/footer HTML source settings.
  - Sources: PR #1849.
  - Rationale: fixes one-shot header/footer sources such as pipes or file descriptors and exposes a direct source-string API without requiring temporary files.
  - Acceptance:
    - [x] `--header-html-source` and `--footer-html-source` work from CLI.
    - [x] C/lib settings expose `header.htmlSource` and `footer.htmlSource` through reflection.
    - [x] Header/footer local HTML sources are read once and reused for measuring and rendering.
    - [x] Existing `--header-html` / `--footer-html` URL behavior remains supported.
    - [x] Smoke test covers source-string header/footer usage.
    - [x] Build and smoke tests pass.
    - [x] Commit separately.
- [ ] Feature 2: base/effective URL for HTML supplied via stdin/API.
  - Sources: PR #20.
  - Rationale: relative CSS/images should be resolvable when input HTML is supplied as a string.
  - Acceptance:
    - [ ] Add a narrowly named load/page setting and CLI option.
    - [ ] Use `QWebFrame::setHtml(data, baseUrl)` only for in-memory HTML.
    - [ ] Smoke test covers stdin HTML resolving a relative asset.
    - [ ] Build and smoke tests pass.
    - [ ] Commit separately.
- [ ] Feature 3: improve internal link target placement for non-anchor element IDs.
  - Sources: PR #4961 / #3942.
  - Rationale: links to large elements should land at the element start rather than an imprecise box location.
  - Acceptance:
    - [ ] Add a focused regression fixture.
    - [ ] Avoid DOM mutations that alter layout unless isolated and proven safe.
    - [ ] Smoke/regression test covers link generation without PDF corruption.
    - [ ] Build and smoke tests pass.
    - [ ] Commit separately.

## Deferred / not in current implementation pass

- [ ] Per-object/page orientation: useful but requires design across pagination, headers/footers, copies, and collate.
- [ ] Extended PDF form support: useful but high-risk and partly Qt-patch dependent.
- [ ] Visual regression harness: useful CI enhancement, but larger than a feature patch.
- [ ] Transparent PDF background: requires product decision because it changes rendering defaults unless hidden behind an option.

## Validation log

- [x] `git diff --check`
- [x] `cd build && qmake ../wkhtmltopdf.pro CONFIG+=silent && make -j2`
- [x] `WKHTMLTOPDF_BINARY=$PWD/build/bin/wkhtmltopdf WKHTMLTOIMAGE_BINARY=$PWD/build/bin/wkhtmltoimage python3 tests/smoke/smoke.py`

## Progress notes

- 2026-05-31: Plan created. Starting Feature 1 first because it is isolated, user-visible, and testable with the current smoke suite.
- 2026-05-31: Feature 1 implemented with CLI/API settings, one-shot local source caching, and smoke coverage for inline source and `/proc/self/fd` header input.
