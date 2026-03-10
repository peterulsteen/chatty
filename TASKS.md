# TASKS — chatty operationalization

Living document. Check off on merge to main.

## Completed

- [x] Bootstrap — CLAUDE.md, TASKS.md, .env.example skeleton, comment out drop_all
- [x] Migrate Poetry → uv (add ruff + pyright to dev deps)
- [x] Bump FastAPI to current version; replace deprecated `@app.on_event` with `lifespan`
- [x] pre-commit hooks (ruff, pyright, deptry, pyproject-fmt, uv-lock, mdformat, hygiene)
- [x] GitHub Actions CI (pre-commit run --all-files as single source of truth)
- [x] Config / env var management (pydantic-settings + .env.example)
- [x] CORS (CORSMiddleware + SocketIO cors_allowed_origins, env-driven)
- [x] /ready readiness endpoint (do not touch existing /health/)
- [x] Add request_id to existing logging middleware
- [x] Multi-stage Dockerfile (CMD: chatty.main:socketio_app)
- [x] docker-compose.yml (app + Postgres service, DATABASE_URL wired via env)
- [x] Alembic skeleton (migration infrastructure — env.py, versions/, not a schema migration)
- [x] Smoke tests in CI (docker compose up --wait + pytest tests_smoke/)
- [x] Terraform skeleton (bootstrap + modules/networking/alb/ecs/rds + dev/staging/prod envs)

## Implement

- [x] Justfile (dev, test, build, up, down — no lint/typecheck, pre-commit owns those)
- [x] `pip-audit` in CI — dependency vulnerability scan against PyPI advisory database
- [x] `trivy` image scan in CI — container CVE scan after docker build (distinct from IaC scan)
- [x] `.github/PULL_REQUEST_TEMPLATE.md`
- [ ] `.github/CODEOWNERS` — require review from specific owners for specific paths
- [ ] Pin GitHub Actions steps to commit SHAs — supply chain hardening (currently using mutable
  version tags)

## Document only (RATIONALE.md)

- [x] Auth/authz approach — JWT + ALB/Cognito design, FastAPI Depends pattern
- [x] CI/CD approach — CD pipeline design (ECR push → ECS rolling deploy → rollback)
- [x] Exposing service to front-end — ALB + CloudFront topology, WebSocket routing
- [x] Auto scaling + load testing — ECS target tracking, Locust baseline approach
- [x] Cloud spend management — tagging strategy, Savings Plans, VPC endpoint savings
- [x] General SDLC — trunk-based dev, PR gates, release strategy, Renovate for dependency updates
- [x] Full DevSecOps pipeline design — shift-left layers (pre-commit), CI scan gates (Trivy,
  pip-audit, checkov), CD gates (secret scanning before ECR push), policy enforcement
  (OPA/Sentinel), image signing (cosign)
- [ ] OpenTelemetry tracing approach — instrumentation design, OTLP exporter, collector sidecar
- [x] Commit signing — require signed commits; document branch protection rule in General SDLC

## Final pass

- [ ] RATIONALE.md + README polish
