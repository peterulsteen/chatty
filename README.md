# chatty
Chatty Backend experimentation

# Local Setup
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

# Testing
```bash
# Unit tests (from app directory)
cd app
uv run pytest -W ignore

# Basic RestAPI smoke test with server running locally
uv run pytest tests_smoke/smoke_test.py

# Basic SocketIO smoke test with server running locally
uv run pytest tests_smoke/smoke_socketio.py
```

# To Do / To Discuss:
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
