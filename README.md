# chatty

[![CI](https://github.com/peterulsteen/chatty/actions/workflows/ci.yml/badge.svg)](https://github.com/peterulsteen/chatty/actions/workflows/ci.yml)

Chatty Backend experimentation

## Local Setup

```bash
# Requires Python 3.11+ and uv (https://docs.astral.sh/uv/getting-started/installation/)
cd app
uv sync

# Wire pre-commit hooks (one-time, after cloning)
uv run pre-commit install

# To run the local server (from app directory)
uv run python run.py

# To see lovely docs in your browser:
# http://localhost:8000/docs
```

## Testing

```bash
# Unit tests (from app directory)
cd app
uv run pytest -W ignore

# Smoke tests — require a running server and database
# Easiest: use docker compose (spins up the full stack)
docker compose up -d --wait
cd app && uv run pytest tests_smoke/ -v -W ignore
docker compose down -v

# Or run against a server already running locally
cd app
uv run pytest tests_smoke/smoke_test.py
uv run pytest tests_smoke/smoke_socketio.py
```

Smoke tests also run automatically in CI as a separate `smoke-test` job after unit tests pass.

## To Do / To Discuss

- dockerize
- basic github actions
- OpenAPI spec generation
- CORS approach
- infra as code approach, incl implied terraform dependency graph
- CI/CD approach
- auth/authz approach
- db migration instrumentation
- config / env var management
- exposing service to front-end layer
- auto scaling, load testing, etc..
- cloud spend management
- general SDLC at this stage of maturity
