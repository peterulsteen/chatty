# RATIONALE.md

Running log of decisions made during operationalization of the chatty backend.
Updated with each task. Never delete entries.

---

## Task 0 — Bootstrap

### Commented out drop_all
`Base.metadata.drop_all` in `main.py` was active in the initial commit — nukes the
DB on every restart. Commented out to prevent data loss in any environment beyond
solo local iteration.

---

## Migrate Poetry → uv

### uv as package manager
uv replaces Poetry for all dependency management and script execution. It is
significantly faster, has first-class support for PEP 621 `[project]` metadata,
and is the direction the Python ecosystem is moving. The `app/` directory remains
the project root — all uv commands run from there.

### hatchling as build backend
hatchling is the recommended build backend for uv-managed projects with a src
layout. It replaces `poetry-core`. `[tool.hatch.build.targets.wheel]` with
`packages = ["src/chatty"]` preserves the existing src layout without changes
to any source files.

### requests moved to dev dependencies
`requests` was listed as a production dependency but is only used in
`tests_smoke/`. Moved to `[dependency-groups] dev` to keep the production
install lean.

### ruff and pyright added to dev dependencies
Added now as dev dependencies even though linting and type-checking tasks come
later. Having them available in the venv immediately allows ad-hoc use and
unblocks those tasks without a separate dep-add commit.

---

## AI Use

This project uses Claude Code (claude-sonnet-4-6) as a pair-programming assistant
throughout the operationalization work. All code changes are reviewed and approved
by the engineer before commit. Claude is used to:

- Draft and refine implementation within task scope
- Catch deprecated patterns and surface trade-offs
- Keep RATIONALE.md, TASKS.md, and README.md consistent with actual changes
- Enforce the atomic change rule (flag when a change touches too many files)

Claude does not autonomously push, merge, or open PRs without explicit instruction.
Commit messages and branch names are chosen by the engineer.
