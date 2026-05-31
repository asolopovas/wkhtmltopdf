# Agent map

Use the repo as source of truth. Keep this file as a map; put durable knowledge in docs, tests, scripts, schemas, generated artifacts, or execution plans.

## Sources

- User docs: `docs/docs.md`, `docs/downloads.md`, `docs/status.md`, `docs/support.md`.
- Maintainer docs: `docs/source-guide.md`, `docs/settings.md`, `docs/apparmor.md`.
- Generated outputs: `docs/usage/wkhtmltopdf.txt`, `docs/libwkhtmltox/`.
- Build/package truth: <https://github.com/wkhtmltopdf/packaging>.
- CI truth: `.github/workflows/official.yml`, `.github/workflows/unpatched.yml`.

## Task loop

1. Inspect code, docs, and existing generated output.
2. Use a brief plan; for risky or multi-step work, check in an execution plan with goal, scope, acceptance criteria, progress, decisions, validation, and debt.
3. Work in an isolated git worktree with disposable env vars, ports, temp dirs, logs, caches, and services.
4. Make the smallest change that meets acceptance criteria.
5. Run the closest local check; capture commands, results, and unavailable checks.
6. Self-review for correctness, security, stale docs, generated-output freshness, and broken links.

## Validation

- Qt 4 unpatched: `qmake-qt4 CONFIG+=silent && make`
- Qt 5 unpatched: `qmake CONFIG+=silent && make`
- Official packages: mirror `.github/workflows/official.yml` in the packaging repo.
- Docs: verify links, issue routing, and generated artifacts.

## Pull requests

Keep PRs small. Include summary, acceptance criteria, validation results, runtime evidence when relevant, and follow-up debt. Escalate only for product judgment, risk, ambiguity, or unavailable validation.
