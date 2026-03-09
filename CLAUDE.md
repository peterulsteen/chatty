# CLAUDE.md — chatty project context

## Project
chatty is a Python FastAPI + SocketIO backend being operationalized as a
platform engineering exercise. The goal is DevOps, infrastructure, and
SDLC best practices — not new features.

## Stack
- Python 3.11
- FastAPI
- python-socketio (AsyncServer, ASGI mount)
- SQLAlchemy (SQLite for local dev)
- uv (package manager — replaces Poetry)
- Docker + docker compose
- GitHub Actions (CI)
- pytest
- structlog (JSON structured logging — already configured and wired)

## Package Layout
src layout — package lives at `app/src/chatty/`.
- `app/pyproject.toml` is the project root for uv
- `app/src/chatty/main.py` is the FastAPI app
- `app/src/chatty/core/` — database, logging, middleware
- `app/src/chatty/routers/` — route handlers
- `app/run.py` — uvicorn entry point

## Critical: uv commands run from app/
pyproject.toml is in `app/`, not at repo root. All uv commands must be
run from the `app/` directory:
  cd app && uv run python run.py
  cd app && uv run pytest -W ignore
  cd app && uv run ruff check src/

## Critical: uvicorn targets socketio_app, not app
The entry point is `chatty.main:socketio_app` — the SocketIO ASGI wrapper
that wraps the FastAPI app. Using `chatty.main:app` starts HTTP but
SocketIO connections fail silently. This applies to run.py, Dockerfile
CMD, and any other invocation.

## Conventions
- All dependencies managed via uv. Never use pip directly.
- pyproject.toml is the single source of truth for deps and tooling config.
- All config via environment variables. No hardcoded values anywhere.
- Secrets via .env locally (gitignored). .env.example is the public contract.
- JSON structured logging only via structlog. No print() statements.
- Type hints on all new functions.
- Tests must pass after every change: cd app && uv run pytest -W ignore

## What NOT to do
- Do not add features beyond what the current task explicitly requires
- Do not modify files not listed in the current task scope
- Do not add dependencies without explicit instruction
- Do not use "latest" Docker image tags
- Do not put secrets or credentials in any tracked file
- Do not use print() — use the structured logger
- Do not combine multiple tasks in one session

## Atomic change rule
If a change touches more than 3-4 files for unrelated reasons,
it is not atomic. Stop and ask for the task to be decomposed further.

## Per-task workflow
Each task has explicit acceptance criteria in TASKS.md.
Read the current task before starting.
Only change what the task scope specifies.
Run acceptance commands from TASKS.md before marking done.
