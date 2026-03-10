# RATIONALE.md

Decisions made during operationalization of the chatty backend, organized by concern.

______________________________________________________________________

## TL;DR

**Key decisions:**

- **Package management**: uv replaces Poetry; src layout unchanged; all config via pydantic-settings
  (12-factor, no hardcoded values).
- **Code quality**: ruff + pyright + deptry enforced at commit via pre-commit. CI runs the same
  hooks as the single source of truth — no separate lint/format steps in CI.
- **Containerization**: Two-stage Docker build. Final stage strips pip/setuptools/wheel (eliminates
  their CVE surface). Non-root user uid 1001. Uvicorn entrypoint is `chatty.main:socketio_app`, not
  `chatty.main:app` — the SocketIO ASGI wrapper must intercept WebSocket upgrades before FastAPI
  middleware.
- **Security posture**: Three-layer DevSecOps — shift-left (gitleaks, ruff, terraform fmt), CI gates
  (Trivy IaC + image, pip-audit), CD gates (planned: cosign, SLSA provenance). All GHA steps pinned
  to full commit SHAs.
- **Auth**: Deferred to the ALB layer (authenticate-cognito/oidc). Application handles authorization
  only, via FastAPI `Depends`.
- **Infrastructure**: Terraform skeleton covers networking → alb + rds → ecs. VPC endpoints
  eliminate NAT Gateway charges. ECR IMMUTABLE tags + ECS circuit breaker enable safe rolling
  deploys and one-command rollback.
- **Database**: Alembic migration infrastructure in place; schema ownership still with `create_all`
  at startup, ready for the first real migration.
- **Observability**: structlog (JSON structured logging + request_id) is layer one. OTel tracing is
  layer two — deferred until an observability backend is chosen; approach documented below.

**Key trade-offs:**

- SQLite is the default for bare local runs (`uv run python run.py` without a `.env`);
  docker-compose and Terraform both provision Postgres, wired via `DATABASE_URL`.
- Docker base images pinned by tag, not digest — digest pinning without Renovate trades a small risk
  for guaranteed staleness; both should be adopted together.
- Trivy suppresses unfixed CVEs (`--ignore-unfixed`) — glibc CVE-2026-0861 has no available fix.
  Explicit policy, not an oversight.
- pip-audit in CI, not pre-commit — advisory database queries are network-dependent; pre-commit
  should be fast and offline-capable.
- Rolling deploy over blue/green — ECS circuit breaker provides automatic rollback; blue/green adds
  operational complexity without improving WebSocket connection drain behavior.

**What was automated:**

- Linting, formatting, type checking (ruff, pyright) — pre-commit + CI
- Dependency vulnerability scanning (pip-audit) — CI
- Container CVE scanning (Trivy image scan) — CI
- IaC security scanning (Trivy IaC + TFLint) — CI
- Smoke tests against a full docker-compose stack — CI

**AI use:** Claude Code (claude-sonnet-4-6) used as a pair-programming assistant throughout. All
changes reviewed and approved before commit. See [AI Use](#ai-use) at the end.

______________________________________________________________________

## Part 1: Implemented

______________________________________________________________________

### Python Application

#### Package management

uv replaces Poetry — significantly faster, first-class PEP 621 `[project]` metadata support, and the
direction the Python ecosystem is moving. All uv commands run from `app/` (the project root).

hatchling replaces `poetry-core` as the build backend. `[tool.hatch.build.targets.wheel]` with
`packages = ["src/chatty"]` preserves the src layout without touching any source files.

`requests` was moved from production to dev dependencies — it is only used in `tests_smoke/`. All
production dependencies have lower and upper bounds (e.g. `>=0.115.0,<1`) to prevent silent breaking
changes on `uv sync`.

#### Library upgrades and deprecation fixes

FastAPI was bumped to current. Breaking changes addressed:

- `@app.on_event("startup"/"shutdown")` → `asynccontextmanager` lifespan pattern (FastAPI 0.93+)
- Pydantic v2: `@validator` → `@field_validator` with `@classmethod`; `class Config` →
  `model_config = ConfigDict(...)`; `Model.from_orm()` → `Model.model_validate()` (requires
  `from_attributes=True`)
- SQLAlchemy 2.0: `sqlalchemy.ext.declarative.declarative_base` → `sqlalchemy.orm.declarative_base`
- `datetime.utcnow()` → `datetime.now(UTC)` — `utcnow()` is deprecated in Python 3.12 and returns a
  naive datetime

`Base.metadata.drop_all` in `main.py` was active in the initial commit, nuking the DB on every
restart. Commented out immediately to prevent data loss beyond solo local iteration.

#### Configuration management

All configuration is injected via environment variables following
[12-factor App](https://12factor.net/config) principle III. `pydantic-settings` reads from the
environment (with `.env` file fallback for local dev), validates types, and exposes a singleton
`settings` object. `.env.example` is the public contract; `.env` is gitignored.

`APP_ENV` drives logging verbosity: `_is_production()` delegates to
`settings.APP_ENV == "production"` — DEBUG in development, INFO in production, no code changes
required to switch environments.

#### API surface

**CORS**: FastAPI's `CORSMiddleware` handles HTTP CORS; SocketIO's `cors_allowed_origins` handles
the WebSocket upgrade independently — FastAPI middleware does not intercept WebSocket handshakes.
Both are wired to `settings.CORS_ORIGINS`, a single source of truth that prevents drift.

**`/ready` readiness endpoint**: Returns `{"status": "ok", "checks": {"api": "ok", "db": "ok"}}`.
The `checks` dict is `dict[str, str]` — extensible without a schema change. Degraded state returns
HTTP 503 so orchestrators remove the instance from the load balancer without restarting it. The DB
check issues a `SELECT 1` — cheap enough for a 10s probe interval. `/ready` is intentionally
distinct from the existing `/health/` liveness probe; both live on the same router with no changes
to `main.py`.

**request_id middleware**: A UUID4 `request_id` is generated per request, bound via
`structlog.contextvars.bind_contextvars()` — automatically included in every downstream log call
with no changes to existing callsites. Written to the `X-Request-ID` response header for client-
side correlation. `clear_contextvars()` runs after the response to prevent leakage across requests
on the same worker.

**OpenAPI spec**: FastAPI serves the spec at runtime (`/docs`, `/openapi.json`). A static export
adds value for API Gateway import or SDK generation — not relevant at this stage, not implemented.

______________________________________________________________________

### Developer Experience

#### pre-commit hooks

Linting, formatting, type checking, and import validation enforced at commit time.
`uv run pre-commit install` wires the hooks; CI runs
`uv --project app run pre-commit run --all-files` as the single source of truth — no separate ruff
or pyright steps in CI.

Hooks:

- **ruff + ruff-format** — replaces flake8, isort, and black; `--fix` auto-corrects safe issues
- **pyright** — static type checking via uv-managed pyright; surfaced real bugs in the existing
  codebase (nullable `request.client` access, SQLAlchemy Column assignment)
- **deptry** — catches undeclared imports (`uvicorn` suppressed as DEP002 — CLI dep; `starlette` as
  DEP003 — intentional transitive dep of FastAPI)
- **pyproject-fmt** — enforces consistent ordering in `pyproject.toml`
- **uv-lock** — keeps `uv.lock` in sync when `pyproject.toml` changes
- **gitleaks** — scans staged files for secrets patterns, repo-wide
- **terraform fmt** — HCL formatting enforced at commit time, same layer as Python formatting
- **trailing-whitespace + end-of-file-fixer** — one-time bulk fix; eliminated permanently going
  forward, keeping diffs meaningful

#### Justfile

`just` is a command runner (not a build system) — no implicit dependency tracking, no DAG, no
stale-file logic, no tab-sensitive syntax. That makes it predictable: `just dev` always runs dev.

Recipes: `dev`, `test`, `build`, `up`, `down`. No `lint` or `typecheck` recipes — pre-commit is the
single source of truth for those; duplicating invocation paths risks drift between local and CI
behavior.

______________________________________________________________________

### Containerization

#### Multi-stage Dockerfile

Two stages: **builder** (`ghcr.io/astral-sh/uv:0.10.9`) runs
`uv sync --frozen --no-dev --no-install-project` into `/build/.venv`; **final** (`python:3.11-slim`)
copies only the venv and `app/src/`.

`--no-install-project` means source changes do not invalidate the dependency cache layer, keeping
iterative builds fast.

The final stage removes pip, setuptools, and wheel
(`python -m pip uninstall -y pip setuptools wheel`) — not needed at runtime and carry CVE surface
area. `PYTHONDONTWRITEBYTECODE=1` and `PYTHONUNBUFFERED=1` are set for container hygiene.

The container runs as non-root (uid 1001, no login shell, no home directory). Base images are pinned
by tag; digest pinning would eliminate tag mutability but requires Renovate to avoid guaranteed
staleness — both should be adopted together.

CMD targets `chatty.main:socketio_app`, not `chatty.main:app`. `socketio.ASGIApp` intercepts
WebSocket upgrades at the raw ASGI level before `BaseHTTPMiddleware` sees the request.
`BaseHTTPMiddleware` does not support WebSocket protocol upgrades; using `app` as the entrypoint
causes SocketIO connections to fail silently.

`.dockerignore` excludes `.git`, `__pycache__`, `.env`, `.venv`, test directories, and `*.db`.

______________________________________________________________________

### Database

#### Alembic skeleton

Alembic is a dev dependency at this stage — migrations run as a deployment step, not inside the app
container. The CD pipeline would run `alembic upgrade head` from a one-off ECS task before the
service update rolls.

`sqlalchemy.url` is intentionally absent from `alembic.ini` — credentials must never live in a
committed config file. `env.py` reads `DATABASE_URL` from `settings`.

`0001_baseline.py` is an empty migration. Its purpose is to establish a migration history starting
point so future `alembic revision --autogenerate` migrations have a parent revision. The existing
tables are created by `Base.metadata.create_all()` at startup; the migration history takes over
schema ownership once the first real schema migration is written.

______________________________________________________________________

### CI Pipeline

#### GitHub Actions structure

Three jobs:

- **`ci`** — `uv sync` → pre-commit → pip-audit → pytest
- **`terraform-security`** — TFLint + Trivy IaC scan (runs in parallel with `ci`)
- **`smoke-test`** — depends on `ci`; docker build → Trivy image scan → docker compose up --wait →
  pytest tests_smoke/

pre-commit runs before pytest (fail-fast on style/type issues). The uv cache is keyed on
`app/uv.lock`.

All `uses:` entries are pinned to full commit SHAs with inline version tag comments (e.g.
`actions/checkout@34e114876b...  # v4`). Mutable version tags are a supply chain risk — if an
upstream action repository is compromised and a tag is moved, the next CI run executes
attacker-controlled code with full access to repository secrets. SHA pinning eliminates this vector;
when Renovate is wired it handles SHA bump PRs automatically.

#### pip-audit

`pip-audit` checks all installed packages against the PyPA advisory database and OSV. It runs in the
`ci` job after `uv sync`, before tests. A failed audit means a known CVE in the dependency tree; the
build should stop.

pre-commit is not the right layer: pip-audit makes network calls to query advisory databases and
operates on the resolved dependency graph, not source files. Pre-commit should be fast and
offline-capable.

#### Trivy image scan

The `smoke-test` job builds the image explicitly (`docker build -t chatty:latest .`) then runs Trivy
before `docker compose up`. If the image contains a known HIGH or CRITICAL CVE, CI fails before the
container ever starts.

`docker-compose.yml` specifies `image: chatty:latest` so compose uses the already-built, already-
scanned image rather than rebuilding — the scanned artifact is exactly what runs in smoke tests.

`--ignore-unfixed: true` suppresses findings with no available remediation (currently glibc
CVE-2026-0861). Blocking on unfixable CVEs generates noise with no actionable remediation path.
Explicit policy, not an oversight.

This scan is distinct from the `terraform-security` job's IaC scan — image scan checks OS packages
and language runtime dependencies inside the container; IaC scan checks Terraform HCL for
misconfigurations.

#### Smoke tests

The `smoke-test` job exercises the full running stack — HTTP endpoints and SocketIO — against a live
server with a real Postgres database. `docker compose up -d --wait` blocks until both `db` and `app`
healthchecks pass before handing off to pytest. The app healthcheck polls `/health/ready`, which
already performs a live DB query — a passing healthcheck means the full stack is correctly wired
before a single test runs.

Teardown runs `docker compose down -v` unconditionally (`if: always()`) to keep runners clean. The
job runs only after `ci` passes — no point burning Docker build time when linting or unit tests are
already failing.

______________________________________________________________________

### Infrastructure (Terraform)

#### Module structure and state backend

Modules split by concern (`networking`, `alb`, `ecs`, `rds`), consumed by environment directories
(`dev`, `staging`, `prod`). Environments share identical structure; only `backend.hcl` (state key)
and `terraform.tfvars` (sizing, toggles) differ. DRY without Terragrunt — the environment IS the
parameter.

Explicit dependency chain:

```
networking                         (no dependencies)
    ├── alb      ← networking      (VPC + public subnets + ALB SG)
    ├── rds      ← networking      (VPC + data subnets + RDS SG)       [optional]
    └── ecs      ← networking      (VPC + private subnets + app SG)
                 ← alb             (target_group_arn)
                 ← rds             (database_url_secret_arn)            [optional]
```

Provisioning order: `networking` → `alb` + `rds` (parallel) → `ecs`.

A `bootstrap/` directory provisions the S3 bucket (versioned, KMS-encrypted) and DynamoDB table for
state locking before any environment is applied. Partial backend configuration (`backend "s3" {}` +
`backend.hcl` at init) keeps bucket names and account IDs out of committed `.tf` files. State is
isolated per environment.

`create_rds = false` in dev, `true` in staging/prod. `count = var.create_rds ? 1 : 0` on the RDS
module call — when disabled, `local.database_url_secret_arn` resolves to empty string and ECS skips
secret injection.

#### Key design decisions

- **ECR `image_tag_mutability = "IMMUTABLE"`** — every deployment requires a new git SHA tag;
  prevents the `:latest` anti-pattern where two tasks run different code under the same tag.
- **`deployment_circuit_breaker { rollback = true }`** — ECS automatically rolls back to the
  previous task definition if new tasks fail their healthcheck within the deployment window.
- **`lifecycle.ignore_changes = [desired_count]`** on ECS service — auto-scaling owns
  `desired_count` after first deploy; Terraform reconciling it would fight the scaler.
- **`enable_deletion_protection = var.environment == "prod"`** — conditional expression demonstrates
  environment-aware config without duplicating resource definitions.
- **`check` blocks (Terraform 1.5+)** — post-apply assertions verify ALB DNS and ECR URL are
  non-empty, catching partial failures that don't error at the resource level.
- **VPC endpoints** (ECR, Secrets Manager, CloudWatch Logs) — routes AWS-internal traffic on the AWS
  backbone, bypassing the NAT Gateway. NAT data processing ($0.045/GB) is the largest hidden cost in
  Fargate deployments; interface endpoints ($0.01/hr + $0.01/GB) are materially cheaper for
  high-frequency AWS API calls.
- **Dual auto-scaling policies** (CPU 70% + ALBRequestCountPerTarget 1,000 req/target) — CPU handles
  compute-bound load; request count handles high-connection, low-CPU WebSocket workloads.

#### DevSecOps tooling

Pre-commit: `terraform fmt` at commit time. CI `terraform-security` job: TFLint with AWS ruleset
(`--recursive`, `--minimum-failure-severity=error`) + Trivy IaC scan (HIGH/CRITICAL block).

`terraform validate` is not wired to pre-commit — it requires `terraform init` with a valid backend,
which is impractical for the partial backend config used here.

HashiCorp changed the Terraform license to BSL in 2023. All HCL in this skeleton is compatible with
OpenTofu (the CNCF-hosted open-source fork) without modification.

#### Known limitations

- **Relative module paths** — `source = "../../modules/..."` couples environments to the monorepo
  layout. Mitigation: version and publish modules to a private Terraform module registry or
  reference via git tags.
- **RDS master password in state** — `random_password.db.result` stored in KMS-encrypted state.
  Mitigation: `manage_master_user_password = true` on `aws_db_instance` delegates credential storage
  and rotation to Secrets Manager — Terraform never sees the password.
- **No secret rotation** — `aws_secretsmanager_secret_rotation` not configured. Compliance
  environments require automated rotation; `manage_master_user_password` handles this natively.
- **No Route 53 / DNS wiring** — ALB outputs a DNS name; DNS is a manual post-apply step. Omitted
  because hosted zone IDs are account-specific.
- **No WAF** — no `aws_wafv2_web_acl` on the ALB. Required for production OWASP Top 10 exposure; an
  optional `waf` module with AWS Managed Rule Groups is the mitigation path.
- **No CloudWatch alarms** — log groups are created but no alarms or SNS topic. An optional
  `monitoring` module is the mitigation path.
- **ECR per environment, not per account** — enterprise pattern is a shared ECR account with
  cross-account pull permissions. Acceptable as-is for single-account deployment.
- **Environment directories are structural copies** — any structural change to `main.tf` must be
  made in three places. Long-term mitigation: Terraform Stacks (HCP Terraform) or Terragrunt.
- **No multi-region failover** — modules are region-agnostic (VPC endpoint names parameterized via
  `data.aws_region.current.name`); active-passive failover would require a second environment
  directory and Route 53 health checks.

______________________________________________________________________

## Part 2: Designed (not yet implemented)

> The following sections document planned approaches and forward-looking architecture decisions.
> Nothing below this line is implemented in this repository. These sections exist to facilitate the
> technical review conversation and establish a direction for production readiness.

______________________________________________________________________

### Auth/authz approach

#### JWT verification at the ALB layer

Authentication is handled at the ALB before requests reach the application. With
`authenticate-cognito` or `authenticate-oidc` actions on the HTTPS listener, the ALB validates the
JWT signature against the IdP's public keys and forwards verified claims as `X-Amzn-Oidc-*` headers.
Unauthenticated requests receive a 401 before touching application code.

This offloads token validation entirely from the application — no JWT library to maintain, no key
rotation logic. Safe because the application is only reachable via the ALB (security group
`aws_security_group.app` allows inbound only from `aws_security_group.alb`).

#### FastAPI authorization via Depends

```python
from fastapi import Depends, Header


def current_user(
    x_amzn_oidc_identity: str = Header(...),
    x_amzn_oidc_data: str = Header(...),
) -> dict:
    """Extract verified claims injected by the ALB."""
    import base64, json

    payload = json.loads(base64.b64decode(x_amzn_oidc_data + "=="))
    return payload


async def get_messages(user: dict = Depends(current_user)) -> list[Message]:
    ...
```

Role or scope checks are added inside `current_user` or as additional layered dependencies.
Authorization logic stays co-located with route definitions and is testable in isolation by
injecting a fake dependency in tests.

#### SocketIO authentication

SocketIO connections authenticate on the initial HTTP upgrade request, which passes through the ALB
like any other request. The `connect` event handler receives the verified headers in `environ`:

```python
@sio.event
async def connect(sid, environ, auth):
    identity = environ.get("HTTP_X_AMZN_OIDC_IDENTITY")
    if not identity:
        raise ConnectionRefusedError("unauthenticated")
    await sio.save_session(sid, {"user": identity})
```

Not yet wired: no Cognito user pool or OIDC provider in Terraform; no ALB listener authenticate
actions; no `current_user` dependency in the application.

______________________________________________________________________

### CI/CD pipeline (deploy job)

Full pipeline on merge to `main`:

```
1. ci job              — pre-commit + pip-audit + pytest
2. terraform-security  — TFLint + Trivy IaC (parallel with ci)
3. smoke-test          — docker build + Trivy image + docker compose + pytest tests_smoke/
4. deploy job          — build → ECR push → ECS task def update → ECS service update
                         (not yet wired; steps 1–3 are the current CI gate)
```

The deploy job would use OIDC-based AWS credentials (no long-lived access keys stored in GitHub),
`aws-actions/amazon-ecs-render-task-definition` to inject the new image into the task definition
JSON, and `aws-actions/amazon-ecs-deploy-task-definition` to register and deploy with steady-state
wait.

Every image is tagged with the git SHA. ECR IMMUTABLE enforcement means a SHA cannot be overwritten.
Rolling back is re-deploying the previous SHA tag — `git revert` + merge + CI run = new SHA = clean
forward rollback. If the circuit breaker fires mid-deployment, ECS restores the previous task
definition automatically.

**Rolling deploy over blue/green**: the circuit breaker provides the key safety property. Blue/
green adds operational complexity (test port listener, weighted target groups) without improving
WebSocket connection drain behavior — existing connections are held open on old tasks during the
drain period regardless of deployment strategy.

______________________________________________________________________

### Exposing the service to the front end

```
Browser → CloudFront → ALB (HTTPS) → ECS Fargate tasks
```

CloudFront provides DDoS protection (Shield Standard included), edge TLS termination, HTTP response
caching, and WAF attachment. CloudFront has supported WebSocket proxying since 2018 — upgrade
requests are forwarded to the origin as-is; a cache behavior for `/socket.io/*` with
`CachingDisabled` prevents interference.

No path-based routing split between HTTP and WebSocket is needed — uvicorn handles both on port 8000
via `socketio_app`. `deregistration_delay` (default 300s) on the ALB target group gives existing
WebSocket connections time to close gracefully during a rolling deploy or scale-in.

Custom domain: Route 53 → CloudFront alias record. CloudFront uses an ACM certificate in `us-east-1`
(required for CloudFront regardless of origin region); ALB uses a regional ACM certificate.

______________________________________________________________________

### Auto scaling and load testing

Two ECS target tracking policies:

- **CPU utilization, target 70%** — handles compute-bound load. 70% leaves headroom for traffic
  spikes before the next task comes online (60–90s Fargate cold start).
- **ALBRequestCountPerTarget, target 1,000** — handles high-connection, low-CPU WebSocket load.
  Without this, CPU-based scaling under-provisions during periods of many open connections.

Targets are starting points to be validated against load test results. [Locust](https://locust.io)
is the recommended tool — Python-based, scriptable for both HTTP and WebSocket via
`locust-plugins SocketIoUser`. Baseline scenarios: (1) HTTP ramp to find single-task CPU ceiling,
(2) WebSocket connection flood to validate request-count scaling, (3) mixed load.

Scale-in conservatism: the default 300s cooldown is intentional for a chat workload. Aggressive
scale-in terminates tasks still holding open WebSocket connections. `deregistration_delay` and
scale-in cooldown should be tuned together.

______________________________________________________________________

### Cloud spend management

Every resource inherits three tags via `provider.default_tags`:

```hcl
Project     = var.project      # "chatty"
Environment = var.environment  # "dev" | "staging" | "prod"
ManagedBy   = "terraform"
```

AWS Cost Explorer slices spend by tag; tag-based cost allocation is available within 24 hours of
enabling it in the Billing console. `ManagedBy = "terraform"` also makes it easy to identify
unmanaged (manual or drift) resources.

Per-environment controls:

- **Dev**: `single_nat_gateway = true` (~$30/month saved), `create_rds = false` (~$25–50/month
  saved), minimum ECS task sizing.
- **Staging**: RDS at `db.t4g.small`; single NAT.
- **Prod**: Multi-AZ NAT and RDS — deliberate spend for HA, visible in `terraform.tfvars` for code
  review.

After 3+ months of stable usage: Compute Savings Plans (1-year, no upfront) reduce Fargate charges
~20–30%; RDS Reserved Instances reduce instance-hours ~40%.

Not yet in Terraform: ECR lifecycle policies (purge untagged images to avoid silent storage
charges); CloudWatch log retention (30-day dev/staging, 90-day prod with S3/Glacier archival).

______________________________________________________________________

### General SDLC

#### Trunk-based development

All work on short-lived feature branches (`feat/`, `fix/`, `chore/`, `docs/`) branched from `main`,
merged via PR, deleted. `main` is always releasable. Branches kept to a single atomic concern —
touching more than 3–4 unrelated files is a signal to decompose.

PR gates — all three CI jobs must pass before merge:

- `ci` — pre-commit + pip-audit + unit tests
- `terraform-security` — TFLint + Trivy IaC
- `smoke-test` — docker build + Trivy image + docker compose + smoke tests

Squash merge only — one commit per PR, linear history on `main`. Rebase keeps feature branches
current before opening PRs.

Branch protection rules (to enable in GitHub settings):

- Require status checks: `ci`, `terraform-security`, `smoke-test`
- Require at least 1 approving review (enforced via CODEOWNERS)
- Dismiss stale reviews on new push
- Restrict force-push to `main`
- Require signed commits (SSH signing is now first-class in GitHub; no GPG toolchain needed)

#### Release strategy

Every merge to `main` is a candidate for staging deployment. Production promotion is a manual
trigger on the CD pipeline (not yet wired). Release artifact is the Docker image tagged with the
full git SHA — no semantic versioning, no tagging ceremony. The SHA ties a running container back to
the exact commit that produced it.

#### Dependency update automation

**Renovate** (over Dependabot): better monorepo support, one PR per dependency group rather than one
per package, more granular scheduling. Planned `.renovaterc` config: Python deps weekly (auto-merge
patch, manual review for minor/major), Terraform providers monthly, Docker digests weekly
(auto-merge), GitHub Actions weekly (auto-merge patch). Not yet implemented.

______________________________________________________________________

### Full DevSecOps pipeline design

The current repository implements layers 1 and 2. This documents the complete intended design.

#### Layer 1: shift-left (pre-commit)

Currently wired: ruff, gitleaks, terraform fmt + TFLint.

Planned additions:

- **Semgrep** — SAST for Python; detects injection patterns, insecure `subprocess` use, hardcoded
  credentials. Community ruleset covers FastAPI and SQLAlchemy patterns.
- **checkov** — IaC policy scanning at authoring time; catches the same Terraform misconfigurations
  as the Trivy IaC CI scan, earlier in the loop.

#### Layer 2: CI scan gates

Currently wired: Trivy IaC (`terraform-security` job), Trivy image scan (`smoke-test` job),
pip-audit (`ci` job).

Planned additions:

- **OPA/Conftest** — policy-as-code for Terraform plan output; enforces organization-specific
  policies (no public S3 buckets, required tags on all resources) too business-specific for
  general-purpose scanners.

#### Layer 3: CD gates (not yet implemented)

- **Secret scan on final artifact** — gitleaks on the image filesystem before ECR push. GitHub's
  native push protection covers the source repository; this gate covers the built artifact.
- **Image signing with cosign** — after ECR push, the image digest is signed with a Sigstore/cosign
  key. ECS task definitions pin to the digest; a policy verifies the signature before allowing
  deployment. Prevents tag mutation attacks; provides a verifiable chain of custody from source
  commit to running container.
- **Sentinel/OPA policy enforcement** — if using HCP Terraform, Sentinel policies run against the
  Terraform plan before apply, enforcing cost controls and compliance requirements that cannot be
  expressed as resource-level checks.

#### Supply chain integrity

- **GHA steps pinned to commit SHAs** — already implemented. Mutable version tags are a supply chain
  risk; SHA pinning eliminates the vector. Renovate handles SHA bump PRs automatically when wired.
- **Minimal `GITHUB_TOKEN` permissions** — the workflow has no `permissions:` block (broad default
  scope). Adding `permissions: contents: read` at the top level and granting only what each job
  needs (e.g. `id-token: write` only for the ECR push job) limits blast radius. Planned as part of
  CD wiring.
- **SBOM generation** — Trivy can output a CycloneDX or SPDX Software Bill of Materials from the
  container image. One additional `trivy image --format cyclonedx` step; increasingly expected for
  compliance with US Executive Order 14028 and the EU Cyber Resilience Act.
- **Commit signing** — requiring GPG or SSH-signed commits via branch protection ensures every
  commit on `main` is cryptographically attributed to a known key. A GitHub repository settings
  change, documented here as a required hardening step before production launch.
- **SLSA provenance** — current build is roughly SLSA Level 1 (scripted, repeatable). Level 2 adds a
  signed provenance attestation via `slsa-github-generator`, establishing a verifiable link from
  source commit to container image digest. Targeting Level 2 as part of the CD pipeline.

#### Severity posture

HIGH and CRITICAL findings block the build; MEDIUM and below are reported but do not fail. Blocking
on MEDIUM in a greenfield project generates noise from unfixed upstream vulnerabilities with no
available remediation. The threshold should be reviewed as the project matures.

______________________________________________________________________

### OpenTelemetry tracing approach

#### Why not implement now

Distributed tracing is observability layer two — structured logging (structlog, already wired) is
layer one. A half-wired OTel setup with no collector and no backend produces no value and adds
maintenance overhead. The decision is to document the approach and implement it when the CD pipeline
and observability backend are chosen.

#### Instrumentation

```python
# app/src/chatty/core/telemetry.py
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor


def configure_tracing(app, engine, service_name: str) -> None:
    resource = Resource.create({"service.name": service_name})
    provider = TracerProvider(resource=resource)
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(provider)
    FastAPIInstrumentor.instrument_app(app)
    SQLAlchemyInstrumentor().instrument(engine=engine)
```

Called once in the lifespan context manager — auto-instruments all FastAPI routes and SQLAlchemy
queries. SocketIO events require manual span creation via `tracer.start_as_current_span()` (no OTel
instrumentation package exists for python-socketio).

#### OTLP and collector

The exporter sends spans via gRPC (port 4317). In local development, an OTel Collector runs as an
additional docker-compose service. In production on ECS, the collector runs as a sidecar in the same
task definition (sharing the task's network namespace); the app sets `OTLP_ENDPOINT=localhost:4317`.

The ALB passes `X-Amzn-Trace-Id` headers on all requests. The OTel SDK extracts this as the parent
span context, linking front-end and back-end traces across the CloudFront → ALB → ECS path.

______________________________________________________________________

## AI Use

This project uses Claude Code (claude-sonnet-4-6) as a pair-programming assistant throughout the
operationalization work. All code changes are reviewed and approved by the engineer before commit.

Claude is used to:

- Draft and refine implementation within task scope
- Catch deprecated patterns and surface trade-offs
- Keep RATIONALE.md, TASKS.md, and README.md consistent with actual changes
- Enforce the atomic change rule (flag when a change touches too many files)

Claude does not autonomously push, merge, or open PRs without explicit instruction. Commit messages
and branch names are chosen by the engineer.
