# RATIONALE.md

Running log of decisions made during operationalization of the chatty backend. Updated with each
task. Never delete entries.

______________________________________________________________________

## Bootstrap

### Commented out drop_all

`Base.metadata.drop_all` in `main.py` was active in the initial commit — nukes the DB on every
restart. Commented out to prevent data loss in any environment beyond solo local iteration.

______________________________________________________________________

## Migrate Poetry → uv

### uv as package manager

uv replaces Poetry for all dependency management and script execution. It is significantly faster,
has first-class support for PEP 621 `[project]` metadata, and is the direction the Python ecosystem
is moving. The `app/` directory remains the project root — all uv commands run from there.

### hatchling as build backend

hatchling is the recommended build backend for uv-managed projects with a src layout. It replaces
`poetry-core`. `[tool.hatch.build.targets.wheel]` with `packages = ["src/chatty"]` preserves the
existing src layout without changes to any source files.

### requests moved to dev dependencies

`requests` was listed as a production dependency but is only used in `tests_smoke/`. Moved to
`[dependency-groups] dev` to keep the production install lean.

### ruff and pyright added to dev dependencies

Added now as dev dependencies even though linting and type-checking tasks come later. Having them
available in the venv immediately allows ad-hoc use and unblocks those tasks without a separate
dep-add commit.

______________________________________________________________________

## Bump FastAPI + fix deprecations

### Version constraints

All production dependencies now have both lower and upper bounds (e.g. `>=0.115.0,<1`). Lower bounds
are set to versions that support the patterns we use; upper bounds cap at the next major version to
prevent silent breaking changes on `uv sync`.

### FastAPI lifespan

`@app.on_event("startup"/"shutdown")` replaced with the `asynccontextmanager` lifespan pattern
introduced in FastAPI 0.93. Startup runs before `yield`, shutdown after. This is the only supported
pattern going forward.

### Pydantic v2 migration

- `@validator` → `@field_validator` with `@classmethod` (v2 requirement)
- Cross-field validation → `@model_validator(mode="after")`
- `class Config` → `model_config = ConfigDict(...)`
- `Model.from_orm(obj)` → `Model.model_validate(obj)` (requires `from_attributes=True` in
  ConfigDict)
- `import re` moved to module level in all schemas (was inline inside validators)

### SQLAlchemy 2.0

`sqlalchemy.ext.declarative.declarative_base` → `sqlalchemy.orm.declarative_base` (the ext path was
deprecated in SQLAlchemy 1.4, removed in 2.0).

### datetime.utcnow()

Replaced with `datetime.now(UTC)` throughout. `utcnow()` is deprecated in Python 3.12 and returns a
naive datetime; `now(UTC)` returns a timezone-aware datetime.

______________________________________________________________________

## pre-commit hooks

### Shift-left enforcement via pre-commit

Linting, formatting, type checking, and import validation are enforced at commit time via pre-commit
hooks, managed as a uv dev dependency. No manual installation required — `uv sync` installs it,
`uv run pre-commit install` wires the git hooks. CI will run `uv run pre-commit run --all-files` as
the single source of truth, eliminating duplication between local and CI check definitions.

### Hook selection

- `ruff` + `ruff-format`: single tool replaces flake8, isort, and black. `--fix` auto-corrects safe
  issues before commit.
- `pyproject-fmt`: enforces consistent ordering and formatting in `pyproject.toml`, which reviewers
  will read carefully.
- `uv-lock`: keeps `uv.lock` in sync automatically when `pyproject.toml` changes.
- `deptry`: catches imports not declared as dependencies. Particularly relevant since `requests` was
  moved from prod to dev.
- `pyright`: static type checking via uv-managed pyright, keeping it in sync with the dev
  environment.
- `trailing-whitespace` + `end-of-file-fixer`: enforced once on first run, causing a bulk whitespace
  fix across the codebase. Cosmetic churn up front, but eliminates it permanently going forward —
  consistent enforcement keeps diffs meaningful.

### deptry suppressions

- `uvicorn` (DEP002): declared as production dep but invoked via CLI, not imported. Legitimate
  runtime dependency.
- `starlette` (DEP003): imported directly in middleware but is a transitive dep of FastAPI.
  Intentional — FastAPI exposes starlette as a first-class surface.

### Pyright fixes surfaced

Pre-commit revealed real type bugs in the existing codebase: `Optional[str]` parameters typed as
`str`, `request.client` nullable access, SQLAlchemy Column assignment. All fixed as part of this
task.

______________________________________________________________________

## GitHub Actions CI

### pre-commit as the single CI gate

CI runs `uv --project app run pre-commit run --all-files` as the sole lint/format/typecheck step. No
separate ruff or pyright steps — pre-commit owns those entirely, eliminating any drift between local
and CI check definitions.

### uv cache via actions/cache

The uv cache directory (from `setup-uv` outputs) is cached keyed on `app/uv.lock`. This avoids
re-downloading packages on every run while ensuring the cache is invalidated when dependencies
change.

### Fail-fast ordering

pre-commit runs before pytest. Fast feedback on style/type issues without waiting for the test
suite.

______________________________________________________________________

## Config / env var management

### 12-factor App configuration

All application configuration is injected via environment variables, following
[12-factor App](https://12factor.net/config) principle III. No config values are hardcoded in
source. `pydantic-settings` reads from the environment (with `.env` file fallback for local dev),
validates types, and exposes a singleton `settings` object imported wherever config is needed.
`.env.example` is the public contract for required variables — `.env` is gitignored.

### Singleton settings object

`config.py` exports `settings = Settings()` at module level. This is imported directly rather than
passed as a dependency, since these are process-level constants that don't vary per-request. Avoids
threading concerns and keeps callsites clean.

### APP_ENV drives logging verbosity

`_is_production()` in `logging.py` now delegates to `settings.APP_ENV == "production"` rather than
hardcoding `False`. DEBUG logging in development, INFO in production — no code changes required to
switch environments.

______________________________________________________________________

## CORS

### Dual CORS configuration

FastAPI's `CORSMiddleware` handles HTTP request CORS (see
[FastAPI CORS docs](https://fastapi.tiangolo.com/tutorial/cors/#use-corsmiddleware)). SocketIO
handles WebSocket upgrade CORS independently via its own `cors_allowed_origins` parameter — FastAPI
middleware does not intercept the WebSocket handshake. Both are wired to `settings.CORS_ORIGINS` so
there is a single source of truth and they cannot drift apart. A comment in `main.py` documents this
coupling explicitly.

### CORS_ORIGINS from environment

`CORS_ORIGINS` is a `list[str]` in `Settings`, populated from the environment. In production, set
`CORS_ORIGINS=["https://your-frontend.com"]`. Defaults to `["http://localhost:3000"]` for local
development.

______________________________________________________________________

## /ready readiness endpoint

### Separate route from /health/

`GET /ready` is added to the existing `APIRouter` in `health.py` — no new router, no changes to
`main.py`. The existing `/health/` route and its `HealthResponse` model are untouched. Readiness and
liveness are intentionally distinct: `/health/` is a liveness probe (is the process alive?);
`/ready` is a readiness probe (is the API ready to serve traffic?). Keeping them on the same router
avoids router proliferation while maintaining the semantic distinction.

### ReadyResponse shape and DB check

Returns `{"status": "ok", "checks": {"api": "ok", "db": "ok"}}`. The `checks` dict is a
`dict[str, str]` — extensible to future dependency checks without a schema change. If any check
fails the top-level status is `"degraded"` and the endpoint returns HTTP 503, so orchestrators
remove the instance from the load balancer without restarting it. The DB check issues a `SELECT 1`
via `SessionLocal` — cheap enough for a 10s probe interval and sufficient to detect a broken
connection.

______________________________________________________________________

## request_id logging middleware

### UUID4 per request, bound to structlog contextvars

A UUID4 `request_id` is generated at the top of `LoggingMiddleware.dispatch()` and bound via
`structlog.contextvars.bind_contextvars()`. structlog's `merge_contextvars` processor is already in
the chain, so every log call within the request — including those in routers and services — emits
`request_id` automatically with no changes to existing callsites.

### X-Request-ID response header

`request_id` is written to `response.headers["X-Request-ID"]` before returning, making it available
to API clients for distributed tracing and support correlation.

### clear_contextvars after response

`structlog.contextvars.clear_contextvars()` is called after the header is set. This prevents
`request_id` from leaking into subsequent requests on the same worker thread.

______________________________________________________________________

## Multi-stage Dockerfile

### Two-stage build: builder + final

The builder stage installs Python dependencies into `/build/.venv` using
`uv sync --frozen --no-dev`. The final stage copies only the venv and application source — no build
tooling, no uv, no lock files — keeping the runtime image lean.

### --no-install-project in builder

`uv sync --no-install-project` installs only dependencies, not the chatty package itself. The source
is copied to `/app/src/` in the final stage and made importable via `PYTHONPATH=/app/src`. This
means changes to application source do not invalidate the dependency cache layer, keeping iterative
builds fast.

### CMD targets socketio_app, not app

`chatty.main:socketio_app` is the uvicorn entrypoint, not `chatty.main:app`. `socketio.ASGIApp`
intercepts WebSocket upgrade requests at the raw ASGI level before they reach FastAPI's
`BaseHTTPMiddleware` stack. `BaseHTTPMiddleware` does not support WebSocket protocol upgrades, so
using `app` as the entrypoint causes SocketIO connections to fail silently.

### Non-root user (uid 1001)

The container runs as a dedicated non-root user created with `useradd --uid 1001`. No home directory
or login shell is created — the user exists solely to drop privileges at runtime.

### Image pinning

Base images are pinned by tag (`python:3.11-slim`, `uv:0.10.9`). Digest SHA pinning
(`python:3.11-slim@sha256:...`) would eliminate tag mutability but requires an automated update
mechanism — pinning without one trades a small risk for a guaranteed staleness problem. The correct
pairing is digest pinning + Renovate. That is a reasonable next step for a production deployment but
out of scope here.

### .dockerignore

`.git`, `__pycache__`, `.env`, `.venv`, test directories, and `*.db` are excluded. This prevents
secrets, local state, and test fixtures from entering the build context or the image.

______________________________________________________________________

## AI Use

This project uses Claude Code (claude-sonnet-4-6) as a pair-programming assistant throughout the
operationalization work. All code changes are reviewed and approved by the engineer before commit.
Claude is used to:

- Draft and refine implementation within task scope
- Catch deprecated patterns and surface trade-offs
- Keep RATIONALE.md, TASKS.md, and README.md consistent with actual changes
- Enforce the atomic change rule (flag when a change touches too many files)

Claude does not autonomously push, merge, or open PRs without explicit instruction. Commit messages
and branch names are chosen by the engineer.
