# chatty

[![CI](https://github.com/peterulsteen/chatty/actions/workflows/ci.yml/badge.svg)](https://github.com/peterulsteen/chatty/actions/workflows/ci.yml)

Chatty Backend experimentation

## Local Setup

```bash
# Requires Python 3.11+ and uv (https://docs.astral.sh/uv/getting-started/installation/)
# Also requires terraform on PATH for the terraform_fmt pre-commit hook.
# Recommended: install via mise (https://mise.jdx.dev/) — `mise install` picks up .mise.toml if present,
# or: mise use terraform@latest
cd app
uv sync

# Wire pre-commit hooks (one-time, after cloning)
uv run pre-commit install

# To run the local server (from app directory)
uv run python run.py

# To see lovely docs in your browser:
# http://localhost:8000/docs
```

## Task runner (optional)

If you have [`just`](https://github.com/casey/just) installed, common commands are available as
short aliases. `just` is purely a quality-of-life helper — every recipe is a thin wrapper around the
same `uv` and `docker` commands documented below.

```bash
just dev    # uv run python run.py (hot reload)
just test   # uv run pytest -W ignore
just build  # docker build -t chatty:latest .
just up     # docker compose up -d --wait
just down   # docker compose down -v
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

## Infrastructure (Terraform)

```bash
# One-time bootstrap — provisions S3 + DynamoDB for state backend
cd terraform/bootstrap
terraform init
terraform apply -var="project=chatty" -var="aws_region=us-east-1"

# Per-environment apply
cd terraform/environments/dev
# Fill in backend.hcl with bootstrap outputs, then:
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# Validate all environments (no AWS credentials required)
cd terraform/environments/dev && terraform init -backend=false && terraform validate
```

Environments: `dev` (single NAT, no RDS), `staging` (RDS enabled), `prod` (Multi-AZ RDS,
`prevent_destroy`, minimum 2 ECS tasks).

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
