# Agent map

Keep this file short. Put durable knowledge in docs, tests, scripts, schemas, or generated artifacts.

## Sources of truth

- Product/user docs: `docs/`, especially `docs/docs.md`, `docs/downloads.md`, `docs/status.md`, and `docs/support.md`.
- Generated CLI help: `docs/usage/wkhtmltopdf.txt`.
- Generated C API docs: `docs/libwkhtmltox/`.
- Build/package system: <https://github.com/wkhtmltopdf/packaging>.
- CI expectations: `.github/workflows/official.yml` and `.github/workflows/unpatched.yml`.

## Work loop

1. Inspect the repo and existing docs before editing.
2. Use a small plan for simple work; write an execution plan for risky or multi-step work.
3. Work in a clean git worktree. Keep task state, generated files, logs, and services isolated.
4. Implement the smallest change that satisfies the acceptance criteria.
5. Run the closest local checks; note any unavailable checks.
6. Self-review the diff for correctness, security, stale docs, and broken links.

## Validation

Use the narrowest applicable check first, then broaden as needed:

- Qt 4 unpatched build: `qmake-qt4 CONFIG+=silent && make`
- Qt 5 unpatched build: `qmake CONFIG+=silent && make`
- Official package builds: use the packaging repo commands mirrored in `.github/workflows/official.yml`.
- Docs: verify changed links, generated-artifact freshness, and issue-template routing.

## Pull requests

Keep PRs small. Include scope, acceptance criteria, validation commands/results, UI or runtime evidence when relevant, and follow-up debt. Escalate only for product judgment, risk, ambiguity, or unavailable validation.
