# Agent map

The repository is the source of truth. Keep durable knowledge in code, tests, scripts, generated docs, or checked-in execution plans; keep this file short.

## Sources

- User docs: `README.md`, `docs/docs.md`, `docs/downloads.md`, `docs/status.md`, `docs/support.md`.
- Maintainer docs: `docs/source-guide.md`, `docs/settings.md`, `docs/apparmor.md`.
- Generated docs: `docs/usage/wkhtmltopdf.txt`, `docs/libwkhtmltox/`.
- Execution plans: `docs/execution-plans/`.
- Build/package truth: `GNUmakefile`, `.github/workflows/`, <https://github.com/wkhtmltopdf/packaging>.

## Task loop

1. Inspect repo sources and generated output.
2. Plan briefly; for risky or multi-step work, add/update an execution plan with goal, scope, acceptance criteria, progress, decisions, validation, and debt.
3. Work in an isolated git worktree when practical; isolate env vars, temp dirs, caches, logs, ports, and services.
4. Make the smallest change that satisfies acceptance criteria.
5. Run the closest local checks and record commands/results.
6. Self-review for correctness, security, stale docs, generated-output freshness, and broken links.
7. Escalate only for judgment, risk, ambiguity, or unavailable validation.

## Checks

- Build/test: `make`, `make test`.
- Qt 4 unpatched: `make QT=4` when dependencies are available.
- Install/package: `make install PREFIX=/path`, `make release DRY_RUN=1`, packaging repo workflows for official packages.
- Docs: verify links and regenerate affected generated artifacts.

## Pull requests

Keep PRs small. Include summary, acceptance criteria, validation commands/results, runtime evidence when relevant, and follow-up debt.
