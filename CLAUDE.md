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
- Type hints on all new functions and return values.
- Tests must pass after every change: cd app && uv run pytest -W ignore

## Naming conventions

- Functions and variables: snake_case
- Classes: PascalCase
- Constants: UPPER_CASE

## FastAPI conventions

- All request and response models defined as Pydantic BaseModel subclasses
- Prefer async endpoints (async def) for consistency
- Each endpoint must have a short description (docstring or FastAPI description param)
- Explicit response_model on every endpoint where possible
- Routes: lowercase, descriptive, snake_case (e.g. /users/{user_id})
- Group related endpoints into routers under app/src/chatty/routers/

## Folder structure

- `.github/` — GitHub Actions workflows, issue/PR templates only
- `terraform/` — infrastructure as code, .tf files, modules, variables
- `app/` — FastAPI app source, uv config, dependencies
- `app/src/chatty/` — main package source
- `app/src/chatty/routers/` — FastAPI routers
- `app/src/chatty/models/` — database models
- `app/src/chatty/schemas/` — Pydantic schemas for requests/responses
- `app/src/chatty/core/` — config, settings, utilities
- `app/tests/` — unit and integration tests
- Do not place code outside these directories unless explicitly documented

## Ambiguity

When requirements, data types, or business logic are ambiguous, ask before implementing. Do not guess.

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

## Before every commit

Update these three files as part of every commit:

- **TASKS.md** — document the completed task
- **RATIONALE.md** — document decisions made in the codebase (not meta/process decisions)
- **README.md** — reflect any changes to setup, usage, or tooling commands
