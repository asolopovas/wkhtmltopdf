# Remaining PR/fork ideas implementation plan

## Goal

Implement the remaining low-priority but useful ideas from screened upstream PRs/forks, while avoiding previously rejected risky/noisy changes and keeping each recommendation in a separate commit.

## Scope

1. Docs-only polish from upstream documentation PRs.
2. Selective compiler-warning cleanup from PR #5075.
3. Windows Unicode command-line argument handling from PR #2858, reimplemented narrowly.
4. CI smoke-test workflow inspired by tdunlap607, without vendoring Qt or packaging churn.

## Out of scope

- No merge of MMFL2022 or tdunlap607 branches as-is.
- No stdout logging changes.
- No broad `wkhtmltox` combined executable from PR #2858.
- No packaging repo consolidation or vendored Qt tree changes.
- No untestable Windows-only behavior beyond a small, reviewable code path and local non-Windows regression build.

## Acceptance criteria

- [x] Each recommendation is implemented in its own commit.
- [x] Existing smoke tests continue to pass locally.
- [x] New/changed behavior has the closest practical test coverage.
- [x] Generated or user-facing docs are updated where relevant.
- [x] Working tree is clean after commits.

## Review findings and implementation decisions

- PR #3817: keep the grammar fixes, but only for the documentation source and generated usage text. Several grammar fixes were already present in source, so the implementation should be a small consistency pass rather than a raw patch.
- PR #4892: use the idea, not the whole patch. Apply only unambiguous user-facing `Qt` capitalization fixes; avoid broad churn in comments or generated sites.
- PR #5075: take only the safe warning fixes. Avoid the old-style signal signature rewrites because they are noisy and can be wrong for const-reference signals. Keep behavior stable.
- PR #2858: do not add the combined `wkhtmltox` executable or broad parser rewrite. Prefer a narrow Windows-only wide-argument capture helper plus centralized command-line string decoding, with Linux smoke coverage for non-ASCII filenames as the closest local regression test.
- tdunlap607 CI branch: take only the smoke-test idea. Do not vendor Qt, move packaging scripts, or change official packaging workflow semantics.

## Feature 1: docs-only polish

Source ideas: PR #3817, PR #4892.

- [x] Fix remaining obvious grammar/spelling issues in generated user docs source (`src/pdf/pdfdocparts.cc`).
- [x] Mirror generated-output updates in `docs/usage/wkhtmltopdf.txt`.
- [x] Apply narrowly scoped user-facing `Qt` capitalization fixes only where unambiguous.
- [x] Validate with `git diff --check`.
- [x] Commit separately.

Acceptance:

- [x] No functional source behavior changes.
- [x] User docs text is clearer and consistent.

## Feature 2: selective compiler-warning cleanup

Source idea: PR #5075.

- [x] Fix null-`ok` handling in settings parsers where missing (review found the risky writes were already guarded; retained that behavior).
- [x] Align constructor initializer order/formatting with declaration order where warning-prone.
- [x] Prefer minimal, safe warning fixes over broad signal rewrites.
- [x] Add/adjust focused tests only if behavior changes; otherwise rely on build diagnostics.
- [x] Validate with build and smoke tests.
- [x] Commit separately.

Acceptance:

- [x] No behavior changes except avoiding null pointer writes in parser helpers.
- [x] Qt 5 local build remains clean enough for the touched files.

## Feature 3: Windows Unicode CLI argument handling

Source idea: PR #2858.

- [x] Inspect current command-line parser architecture and identify the narrowest Windows-only conversion point.
- [x] Reimplement Unicode argv handling without adding a combined `wkhtmltox` executable.
- [x] Preserve current non-Windows argument parsing behavior.
- [x] Add unit-level or smoke-style coverage where practical; if Windows execution is unavailable, add a helper-level test or document validation limits.
- [x] Validate local Linux build/smoke tests to prevent regressions.
- [x] Commit separately.

Acceptance:

- [x] Windows builds can receive Unicode paths through Qt/Windows wide arguments instead of lossy local-8-bit conversion.
- [x] Non-Windows behavior remains unchanged.
- [x] Validation limitations are recorded in the commit/plan.

## Feature 4: CI smoke-test workflow

Source idea: tdunlap607 CI smoke-test commits.

- [x] Add a focused CI smoke-test path to the existing Qt 5 unpatched job instead of duplicating a build.
- [x] Run `tests/smoke/smoke.py` against produced binaries.
- [x] Keep caches/artifacts conservative and avoid changing packaging truth.
- [x] Validate YAML syntax locally where tooling is available.
- [x] Commit separately.

Acceptance:

- [x] CI includes an executable smoke-test path for core binaries.
- [x] Workflow remains small and maintainable.
- [x] No Qt submodule vendoring or packaging consolidation is introduced.

## Validation log

- [x] `git diff --check`
- [x] `python3 -m py_compile tests/smoke/smoke.py`
- [x] `cd build && qmake ../wkhtmltopdf.pro CONFIG+=silent && make -j2`
- [x] `WKHTMLTOPDF_BINARY=$PWD/build/bin/wkhtmltopdf WKHTMLTOIMAGE_BINARY=$PWD/build/bin/wkhtmltoimage python3 tests/smoke/smoke.py`
- [x] CI YAML validation if available.

## Progress notes

- 2026-05-31: Plan created before implementation, per request.
- 2026-05-31: Reviewed source PRs/forks, reimplemented only the focused parts, and kept each recommendation in a separate commit.
