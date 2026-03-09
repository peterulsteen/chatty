# TASKS — chatty operationalization

Living document. Check off on merge to main. Never delete entries.

- [x] Bootstrap — CLAUDE.md, TASKS.md, .env.example skeleton, comment out drop_all
- [x] Migrate Poetry → uv (add ruff + pyright to dev deps)
- [x] Bump FastAPI to current version; replace deprecated `@app.on_event` with `lifespan`
- [x] pre-commit hooks (ruff, pyright, deptry, pyproject-fmt, uv-lock, hygiene)
- [x] GitHub Actions CI (pre-commit run --all-files as single source of truth)
- [ ] Config / env var management (pydantic-settings + .env.example)
- [ ] CORS (CORSMiddleware + SocketIO cors_allowed_origins, env-driven)
- [ ] /ready readiness endpoint (do not touch existing /health/)
- [ ] Add request_id to existing logging middleware
- [ ] Multi-stage Dockerfile (CMD: chatty.main:socketio_app)
- [ ] docker-compose.yml
- [ ] Justfile (dev, test, lint, typecheck, spec, build, up, down)
- [ ] OpenAPI spec export script
- [ ] GitHub Actions CI (lint, typecheck, test)
- [ ] RATIONALE.md + README polish
