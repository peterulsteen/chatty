# TASKS — chatty operationalization

Living document. Check off on merge to main. Never delete entries.

- [ ] 0. Bootstrap — CLAUDE.md, TASKS.md, .env.example skeleton, comment out drop_all
- [ ] 1. Migrate Poetry → uv (add ruff + pyright to dev deps)
- [ ] 1a. Bump FastAPI to current version; replace deprecated `@app.on_event` with `lifespan`
- [ ] 2. Config / env var management (pydantic-settings + .env.example)
- [ ] 3. CORS (CORSMiddleware + SocketIO cors_allowed_origins, env-driven)
- [ ] 4. /ready readiness endpoint (do not touch existing /health/)
- [ ] 5. Add request_id to existing logging middleware
- [ ] 6. Multi-stage Dockerfile (CMD: chatty.main:socketio_app)
- [ ] 7. docker-compose.yml
- [ ] 8. Justfile (dev, test, lint, typecheck, spec, build, up, down)
- [ ] 9. OpenAPI spec export script
- [ ] 10. GitHub Actions CI (lint, typecheck, test)
- [ ] 11. RATIONALE.md + README polish
