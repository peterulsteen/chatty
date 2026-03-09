# RATIONALE.md

Running log of decisions made during operationalization of the chatty backend.
Updated with each task. Never delete entries.

---

## Bootstrap

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

## Bump FastAPI + fix deprecations

### Version constraints

All production dependencies now have both lower and upper bounds (e.g. `>=0.115.0,<1`).
Lower bounds are set to versions that support the patterns we use; upper bounds cap at
the next major version to prevent silent breaking changes on `uv sync`.

### FastAPI lifespan

`@app.on_event("startup"/"shutdown")` replaced with the `asynccontextmanager` lifespan
pattern introduced in FastAPI 0.93. Startup runs before `yield`, shutdown after. This
is the only supported pattern going forward.

### Pydantic v2 migration

- `@validator` → `@field_validator` with `@classmethod` (v2 requirement)
- Cross-field validation → `@model_validator(mode="after")`
- `class Config` → `model_config = ConfigDict(...)`
- `Model.from_orm(obj)` → `Model.model_validate(obj)` (requires `from_attributes=True` in ConfigDict)
- `import re` moved to module level in all schemas (was inline inside validators)

### SQLAlchemy 2.0

`sqlalchemy.ext.declarative.declarative_base` → `sqlalchemy.orm.declarative_base`
(the ext path was deprecated in SQLAlchemy 1.4, removed in 2.0).

### datetime.utcnow()

Replaced with `datetime.now(UTC)` throughout. `utcnow()` is deprecated in Python 3.12
and returns a naive datetime; `now(UTC)` returns a timezone-aware datetime.

---

## pre-commit hooks

### Shift-left enforcement via pre-commit

Linting, formatting, type checking, and import validation are enforced at commit time
via pre-commit hooks, managed as a uv dev dependency. No manual installation required —
`uv sync` installs it, `uv run pre-commit install` wires the git hooks. CI will run
`uv run pre-commit run --all-files` as the single source of truth, eliminating
duplication between local and CI check definitions.

### Hook selection

- `ruff` + `ruff-format`: single tool replaces flake8, isort, and black. `--fix` auto-corrects safe issues before commit.
- `pyproject-fmt`: enforces consistent ordering and formatting in `pyproject.toml`, which reviewers will read carefully.
- `uv-lock`: keeps `uv.lock` in sync automatically when `pyproject.toml` changes.
- `deptry`: catches imports not declared as dependencies. Particularly relevant since `requests` was moved from prod to dev.
- `pyright`: static type checking via uv-managed pyright, keeping it in sync with the dev environment.
- `trailing-whitespace` + `end-of-file-fixer`: enforced once on first run, causing a bulk whitespace fix across the codebase. Cosmetic churn up front, but eliminates it permanently going forward — consistent enforcement keeps diffs meaningful.

### deptry suppressions

- `uvicorn` (DEP002): declared as production dep but invoked via CLI, not imported. Legitimate runtime dependency.
- `starlette` (DEP003): imported directly in middleware but is a transitive dep of FastAPI. Intentional — FastAPI exposes starlette as a first-class surface.

### Pyright fixes surfaced

Pre-commit revealed real type bugs in the existing codebase: `Optional[str]` parameters
typed as `str`, `request.client` nullable access, SQLAlchemy Column assignment.
All fixed as part of this task.

---

## GitHub Actions CI

### pre-commit as the single CI gate
CI runs `uv --project app run pre-commit run --all-files` as the sole lint/format/typecheck
step. No separate ruff or pyright steps — pre-commit owns those entirely, eliminating
any drift between local and CI check definitions.

### uv cache via actions/cache
The uv cache directory (from `setup-uv` outputs) is cached keyed on `app/uv.lock`.
This avoids re-downloading packages on every run while ensuring the cache is invalidated
when dependencies change.

### Fail-fast ordering
pre-commit runs before pytest. Fast feedback on style/type issues without waiting for
the test suite.

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
