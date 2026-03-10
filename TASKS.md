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

## Implement

- [ ] docker-compose.yml (app + Postgres service, DATABASE_URL wired via env)
- [ ] Alembic skeleton (migration infrastructure — env.py, versions/, not a schema migration)
- [ ] Terraform skeleton (VPC + ECS + RDS resource graph demonstrating dependency order)
- [ ] Justfile (dev, test, build, up, down — no lint/typecheck, pre-commit owns those)

## Document only (RATIONALE.md)

- [ ] Auth/authz approach — JWT + ALB/Cognito design, FastAPI Depends pattern
- [ ] CI/CD approach — CD pipeline design (ECR push → ECS rolling deploy → rollback)
- [ ] Exposing service to front-end — ALB + CloudFront topology, WebSocket routing
- [ ] Auto scaling + load testing — ECS target tracking, Locust baseline approach
- [ ] Cloud spend management — tagging strategy, Savings Plans, VPC endpoint savings
- [ ] General SDLC — trunk-based dev, PR gates, release strategy

## Final pass

- [ ] RATIONALE.md + README polish
