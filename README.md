# chatty

[![CI](https://github.com/peterulsteen/chatty/actions/workflows/ci.yml/badge.svg)](https://github.com/peterulsteen/chatty/actions/workflows/ci.yml)

Chatty is a FastAPI + python-socketio backend, operationalized as a platform engineering exercise.
The goal is DevOps, infrastructure, and SDLC best practices — not new features.

## Quickstart

```bash
# Requires Docker — https://docs.docker.com/get-docker/
docker compose up -d --wait

# Verify the stack is healthy
curl http://localhost:8000/health/ready
# {"status": "ok", "db": "ok"}

# Browse the API docs
open http://localhost:8000/docs

# Tear down
docker compose down -v
```

If you have [`just`](https://github.com/casey/just) installed: `just up` / `just down`.

## Local Development Setup

```bash
# Requires Python 3.11+ and uv — https://docs.astral.sh/uv/
cd app
uv sync

# Wire pre-commit hooks (one-time after cloning)
uv run pre-commit install

# Run with hot reload
uv run python run.py
# or: just dev
```

> Terraform's `terraform_fmt` pre-commit hook requires `terraform` on PATH. Recommended: install via
> [mise](https://mise.jdx.dev/) — `mise use terraform@latest`.

## Testing

```bash
# Unit tests
cd app && uv run pytest -W ignore
# or: just test

# Smoke tests against the full containerized stack
docker compose up -d --wait
cd app && uv run pytest tests_smoke/ -v -W ignore
docker compose down -v
```

CI runs unit tests, smoke tests, dependency audit (`pip-audit`), and container image scanning
(Trivy) automatically on every PR.

## Infrastructure (Terraform)

Full 3-tier AWS skeleton: VPC/subnets/NAT, ALB, ECS Fargate, RDS Postgres, Secrets Manager, VPC
endpoints. Three environments: `dev`, `staging`, `prod`.

```bash
# One-time bootstrap — provisions S3 + DynamoDB for Terraform state
cd terraform/bootstrap
terraform init && terraform apply -var="project=chatty" -var="aws_region=us-east-1"

# Per-environment deploy
cd terraform/environments/dev
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# Validate all environments (no AWS credentials required)
cd terraform/environments/dev && terraform init -backend=false && terraform validate
```

See `RATIONALE.md` for module structure, design decisions, and known limitations.

## What Was Implemented

All items from the original README TODO list have been addressed:

- **Dockerize** — multi-stage Dockerfile (builder + final), non-root user, pip/wheel stripped from
  final image to eliminate CVEs
- **docker-compose** — app + Postgres with health checks; `docker compose up --wait` blocks until
  healthy
- **GitHub Actions CI** — 3-job pipeline: `ci` (pre-commit, pip-audit, unit tests),
  `terraform-security` (TFLint, Trivy IaC scan), `smoke-test` (Trivy image scan, compose up, smoke
  tests)
- **OpenAPI spec** — FastAPI auto-generates at `/docs` and `/redoc`
- **CORS** — `CORSMiddleware` + SocketIO `cors_allowed_origins`, env-driven
- **Infrastructure as code** — Terraform skeleton: networking, ALB, ECS Fargate, RDS, 3
  environments, VPC endpoints, DevSecOps tooling (TFLint, Trivy)
- **Config / env var management** — `pydantic-settings` + `.env.example`; all config via environment
  variables, no hardcoded values
- **DB migration instrumentation** — Alembic skeleton wired to the app database URL
- **Readiness endpoint** — `GET /health/ready` checks DB connectivity; suitable for ALB health
  checks and orchestrator probes
- **Structured logging** — `structlog` JSON logging with `request_id` bound per request via
  middleware
- **DevSecOps** — `gitleaks` secrets scanning, `pip-audit` dependency audit, Trivy IaC + image scan,
  GitHub Actions steps pinned to commit SHAs
- **SDLC** — PR template, `CODEOWNERS`, Justfile, squash-merge discipline

Design-only (documented in `RATIONALE.md`, not yet wired in code):

- CI/CD pipeline — ECR push → ECS rolling deploy → rollback strategy
- Auth/authz — JWT verification at ALB, FastAPI `Depends` pattern, SocketIO auth
- Exposing to front end — CloudFront + ALB topology, WebSocket routing
- Auto scaling + load testing — ECS target tracking, Locust approach
- OpenTelemetry — instrumentation design, OTLP exporter, collector sidecar
- Full DevSecOps pipeline — checkov, Semgrep, cosign, SLSA provenance, SBOM
- Cloud spend management — tagging strategy, VPC endpoint savings, Savings Plans
- General SDLC — trunk-based dev, PR gates, Renovate for dependency updates

## Next Steps (With More Time)

- **CD pipeline** — wire ECR push + ECS rolling deploy; add `GITHUB_TOKEN` minimal permissions and
  SLSA provenance attestation
- **Renovate** — `.renovaterc` for automated dependency and SHA updates (Python, Terraform, Docker,
  GitHub Actions)
- **OTel** — `FastAPIInstrumentor` + collector sidecar in docker-compose; backend TBD
- **Auth/authz** — Cognito user pool in Terraform, ALB `authenticate-cognito` listener rule,
  `current_user` Depends in FastAPI
- **SBOM** — `trivy image --format cyclonedx` step in CI, attached as build artifact
- **Branch protection** — require signed commits, all 3 CI jobs as required status checks
