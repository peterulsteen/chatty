# RATIONALE.md

Running log of decisions made during operationalization of the chatty backend. Updated with each
task. Never delete entries.

______________________________________________________________________

## Bootstrap

### Commented out drop_all

`Base.metadata.drop_all` in `main.py` was active in the initial commit — nukes the DB on every
restart. Commented out to prevent data loss in any environment beyond solo local iteration.

______________________________________________________________________

## Migrate Poetry → uv

### uv as package manager

uv replaces Poetry for all dependency management and script execution. It is significantly faster,
has first-class support for PEP 621 `[project]` metadata, and is the direction the Python ecosystem
is moving. The `app/` directory remains the project root — all uv commands run from there.

### hatchling as build backend

hatchling is the recommended build backend for uv-managed projects with a src layout. It replaces
`poetry-core`. `[tool.hatch.build.targets.wheel]` with `packages = ["src/chatty"]` preserves the
existing src layout without changes to any source files.

### requests moved to dev dependencies

`requests` was listed as a production dependency but is only used in `tests_smoke/`. Moved to
`[dependency-groups] dev` to keep the production install lean.

### ruff and pyright added to dev dependencies

Added now as dev dependencies even though linting and type-checking tasks come later. Having them
available in the venv immediately allows ad-hoc use and unblocks those tasks without a separate
dep-add commit.

______________________________________________________________________

## Bump FastAPI + fix deprecations

### Version constraints

All production dependencies now have both lower and upper bounds (e.g. `>=0.115.0,<1`). Lower bounds
are set to versions that support the patterns we use; upper bounds cap at the next major version to
prevent silent breaking changes on `uv sync`.

### FastAPI lifespan

`@app.on_event("startup"/"shutdown")` replaced with the `asynccontextmanager` lifespan pattern
introduced in FastAPI 0.93. Startup runs before `yield`, shutdown after. This is the only supported
pattern going forward.

### Pydantic v2 migration

- `@validator` → `@field_validator` with `@classmethod` (v2 requirement)
- Cross-field validation → `@model_validator(mode="after")`
- `class Config` → `model_config = ConfigDict(...)`
- `Model.from_orm(obj)` → `Model.model_validate(obj)` (requires `from_attributes=True` in
  ConfigDict)
- `import re` moved to module level in all schemas (was inline inside validators)

### SQLAlchemy 2.0

`sqlalchemy.ext.declarative.declarative_base` → `sqlalchemy.orm.declarative_base` (the ext path was
deprecated in SQLAlchemy 1.4, removed in 2.0).

### datetime.utcnow()

Replaced with `datetime.now(UTC)` throughout. `utcnow()` is deprecated in Python 3.12 and returns a
naive datetime; `now(UTC)` returns a timezone-aware datetime.

______________________________________________________________________

## pre-commit hooks

### Shift-left enforcement via pre-commit

Linting, formatting, type checking, and import validation are enforced at commit time via pre-commit
hooks, managed as a uv dev dependency. No manual installation required — `uv sync` installs it,
`uv run pre-commit install` wires the git hooks. CI will run `uv run pre-commit run --all-files` as
the single source of truth, eliminating duplication between local and CI check definitions.

### Hook selection

- `ruff` + `ruff-format`: single tool replaces flake8, isort, and black. `--fix` auto-corrects safe
  issues before commit.
- `pyproject-fmt`: enforces consistent ordering and formatting in `pyproject.toml`, which reviewers
  will read carefully.
- `uv-lock`: keeps `uv.lock` in sync automatically when `pyproject.toml` changes.
- `deptry`: catches imports not declared as dependencies. Particularly relevant since `requests` was
  moved from prod to dev.
- `pyright`: static type checking via uv-managed pyright, keeping it in sync with the dev
  environment.
- `trailing-whitespace` + `end-of-file-fixer`: enforced once on first run, causing a bulk whitespace
  fix across the codebase. Cosmetic churn up front, but eliminates it permanently going forward —
  consistent enforcement keeps diffs meaningful.

### deptry suppressions

- `uvicorn` (DEP002): declared as production dep but invoked via CLI, not imported. Legitimate
  runtime dependency.
- `starlette` (DEP003): imported directly in middleware but is a transitive dep of FastAPI.
  Intentional — FastAPI exposes starlette as a first-class surface.

### Pyright fixes surfaced

Pre-commit revealed real type bugs in the existing codebase: `Optional[str]` parameters typed as
`str`, `request.client` nullable access, SQLAlchemy Column assignment. All fixed as part of this
task.

______________________________________________________________________

## GitHub Actions CI

### pre-commit as the single CI gate

CI runs `uv --project app run pre-commit run --all-files` as the sole lint/format/typecheck step. No
separate ruff or pyright steps — pre-commit owns those entirely, eliminating any drift between local
and CI check definitions.

### uv cache via actions/cache

The uv cache directory (from `setup-uv` outputs) is cached keyed on `app/uv.lock`. This avoids
re-downloading packages on every run while ensuring the cache is invalidated when dependencies
change.

### Fail-fast ordering

pre-commit runs before pytest. Fast feedback on style/type issues without waiting for the test
suite.

______________________________________________________________________

## Config / env var management

### 12-factor App configuration

All application configuration is injected via environment variables, following
[12-factor App](https://12factor.net/config) principle III. No config values are hardcoded in
source. `pydantic-settings` reads from the environment (with `.env` file fallback for local dev),
validates types, and exposes a singleton `settings` object imported wherever config is needed.
`.env.example` is the public contract for required variables — `.env` is gitignored.

### Singleton settings object

`config.py` exports `settings = Settings()` at module level. This is imported directly rather than
passed as a dependency, since these are process-level constants that don't vary per-request. Avoids
threading concerns and keeps callsites clean.

### APP_ENV drives logging verbosity

`_is_production()` in `logging.py` now delegates to `settings.APP_ENV == "production"` rather than
hardcoding `False`. DEBUG logging in development, INFO in production — no code changes required to
switch environments.

______________________________________________________________________

## CORS

### Dual CORS configuration

FastAPI's `CORSMiddleware` handles HTTP request CORS (see
[FastAPI CORS docs](https://fastapi.tiangolo.com/tutorial/cors/#use-corsmiddleware)). SocketIO
handles WebSocket upgrade CORS independently via its own `cors_allowed_origins` parameter — FastAPI
middleware does not intercept the WebSocket handshake. Both are wired to `settings.CORS_ORIGINS` so
there is a single source of truth and they cannot drift apart. A comment in `main.py` documents this
coupling explicitly.

### CORS_ORIGINS from environment

`CORS_ORIGINS` is a `list[str]` in `Settings`, populated from the environment. In production, set
`CORS_ORIGINS=["https://your-frontend.com"]`. Defaults to `["http://localhost:3000"]` for local
development.

______________________________________________________________________

## /ready readiness endpoint

### Separate route from /health/

`GET /ready` is added to the existing `APIRouter` in `health.py` — no new router, no changes to
`main.py`. The existing `/health/` route and its `HealthResponse` model are untouched. Readiness and
liveness are intentionally distinct: `/health/` is a liveness probe (is the process alive?);
`/ready` is a readiness probe (is the API ready to serve traffic?). Keeping them on the same router
avoids router proliferation while maintaining the semantic distinction.

### ReadyResponse shape and DB check

Returns `{"status": "ok", "checks": {"api": "ok", "db": "ok"}}`. The `checks` dict is a
`dict[str, str]` — extensible to future dependency checks without a schema change. If any check
fails the top-level status is `"degraded"` and the endpoint returns HTTP 503, so orchestrators
remove the instance from the load balancer without restarting it. The DB check issues a `SELECT 1`
via `SessionLocal` — cheap enough for a 10s probe interval and sufficient to detect a broken
connection.

______________________________________________________________________

## request_id logging middleware

### UUID4 per request, bound to structlog contextvars

A UUID4 `request_id` is generated at the top of `LoggingMiddleware.dispatch()` and bound via
`structlog.contextvars.bind_contextvars()`. structlog's `merge_contextvars` processor is already in
the chain, so every log call within the request — including those in routers and services — emits
`request_id` automatically with no changes to existing callsites.

### X-Request-ID response header

`request_id` is written to `response.headers["X-Request-ID"]` before returning, making it available
to API clients for distributed tracing and support correlation.

### clear_contextvars after response

`structlog.contextvars.clear_contextvars()` is called after the header is set. This prevents
`request_id` from leaking into subsequent requests on the same worker thread.

______________________________________________________________________

## Multi-stage Dockerfile

### Two-stage build: builder + final

The builder stage installs Python dependencies into `/build/.venv` using
`uv sync --frozen --no-dev`. The final stage copies only the venv and application source — no build
tooling, no uv, no lock files — keeping the runtime image lean.

### --no-install-project in builder

`uv sync --no-install-project` installs only dependencies, not the chatty package itself. The source
is copied to `/app/src/` in the final stage and made importable via `PYTHONPATH=/app/src`. This
means changes to application source do not invalidate the dependency cache layer, keeping iterative
builds fast.

### CMD targets socketio_app, not app

`chatty.main:socketio_app` is the uvicorn entrypoint, not `chatty.main:app`. `socketio.ASGIApp`
intercepts WebSocket upgrade requests at the raw ASGI level before they reach FastAPI's
`BaseHTTPMiddleware` stack. `BaseHTTPMiddleware` does not support WebSocket protocol upgrades, so
using `app` as the entrypoint causes SocketIO connections to fail silently.

### Non-root user (uid 1001)

The container runs as a dedicated non-root user created with `useradd --uid 1001`. No home directory
or login shell is created — the user exists solely to drop privileges at runtime.

### Image pinning

Base images are pinned by tag (`python:3.11-slim`, `uv:0.10.9`). Digest SHA pinning
(`python:3.11-slim@sha256:...`) would eliminate tag mutability but requires an automated update
mechanism — pinning without one trades a small risk for a guaranteed staleness problem. The correct
pairing is digest pinning + Renovate. That is a reasonable next step for a production deployment but
out of scope here.

### .dockerignore

`.git`, `__pycache__`, `.env`, `.venv`, test directories, and `*.db` are excluded. This prevents
secrets, local state, and test fixtures from entering the build context or the image.

______________________________________________________________________

## OpenAPI spec export

FastAPI generates and serves the OpenAPI spec at runtime (`/openapi.json`, `/docs`). A static export
script adds value for specific tooling — API Gateway import, SDK generation, committing the spec to
version control for PR diffs — but none of those workflows are relevant at this stage. Not
implemented; not a gap worth discussing in the interview.

______________________________________________________________________

## Alembic skeleton

### Alembic as dev dependency

Alembic is a dev dependency at this stage because migrations are run as a deployment step, not
inside the app container. In production the CD pipeline runs `alembic upgrade head` against the
database before the ECS service update rolls — this can be done from a separate migration task
definition or a one-off ECS task using the same image with alembic installed. If a single image
needs to serve both roles, alembic moves to production dependencies.

### sqlalchemy.url intentionally absent from alembic.ini

Credentials must never live in a config file committed to version control. `env.py` reads
`DATABASE_URL` from `settings` (pydantic-settings), which sources it from the environment. The
`alembic.ini` has a comment marking the absence as intentional, not accidental.

### Baseline migration

`0001_baseline.py` is an empty migration — no schema changes. Its purpose is to establish a
migration history starting point so that future `alembic revision --autogenerate` migrations have a
parent revision and `alembic upgrade head` has somewhere to start from. The existing tables are
currently created by `Base.metadata.create_all()` at app startup; the migration history will take
over schema ownership once the first real schema migration is written.

______________________________________________________________________

## Smoke tests in CI

Smoke tests exercise the full running stack — HTTP endpoints and SocketIO — against a live server
with a real Postgres database. They live in `app/tests_smoke/` and were previously run manually
only.

A dedicated `smoke-test` job was added to `ci.yml` that runs after the `ci` job (pre-commit + unit
tests) passes. It uses `docker compose up -d --wait`, which blocks until both `db` and `app`
healthchecks pass before handing off to pytest. The app healthcheck polls `/health/ready`, which
already performs a live DB query — so a passing healthcheck means the full stack is wired correctly
before a single smoke test runs.

The job tears down with `docker compose down -v` (always, even on failure) to keep runners clean.

Sequencing `smoke-test` after `ci` avoids burning Docker build time when linting or unit tests are
already failing.

______________________________________________________________________

## Terraform skeleton

### Module structure

Modules are split by concern (`networking`, `alb`, `ecs`, `rds`) and consumed by environment
directories (`environments/dev`, `environments/staging`, `environments/prod`). The environment
directories contain `main.tf`, `variables.tf`, and `outputs.tf` that are structurally identical
across all three environments. Only `backend.hcl` (state key) and `terraform.tfvars` (sizing,
toggles) differ per environment. This makes the configuration DRY without Terragrunt — the
environments ARE the parameters.

### State backend bootstrap

A `bootstrap/` directory provisions the S3 bucket (versioned, KMS-encrypted) and DynamoDB table (for
state locking) before any environment is applied. This is run once per AWS account. State files are
isolated per environment: `chatty/dev/terraform.tfstate`, `chatty/staging/terraform.tfstate`,
`chatty/prod/terraform.tfstate`. Partial backend configuration (`backend "s3" {}` in `main.tf` +
`backend.hcl` passed at init) keeps bucket names and account IDs out of committed `.tf` files.

### Dependency graph and provisioning order

The explicit module dependency chain is visible in `environments/*/main.tf`:

```
networking                         (no dependencies)
    ├── alb      ← networking      (VPC + public subnets + ALB SG)
    ├── rds      ← networking      (VPC + data subnets + RDS SG)       [optional]
    └── ecs      ← networking      (VPC + private subnets + app SG)
                 ← alb             (target_group_arn, alb_arn_suffix)
                 ← rds             (database_url_secret_arn)            [optional]
```

Provisioning order: `networking` → `alb` + `rds` (parallel) → `ecs`.

### RDS optional pattern

`create_rds = false` in dev tfvars, `true` in staging/prod. The environment uses
`count = var.create_rds ? 1 : 0` on the RDS module call. When disabled,
`local.database_url_secret_arn` resolves to an empty string and the ECS module skips secret
injection. The DATABASE_URL is provided via another mechanism (docker compose locally, or a
pre-existing secret in shared dev environments).

### Key design decisions

- `image_tag_mutability = "IMMUTABLE"` on ECR: every deployment must use a new git SHA tag; prevents
  the `latest` anti-pattern where two tasks run different code under the same tag.
- `deployment_circuit_breaker { rollback = true }`: ECS automatically rolls back to the previous
  task definition if the new deployment fails to reach steady state.
- `lifecycle.ignore_changes = [desired_count]` on ECS service: auto-scaling owns desired_count after
  first deploy; Terraform reconciling it would fight the scaler.
- `enable_deletion_protection = var.environment == "prod"` on ALB: conditional expression
  demonstrates environment-aware resource configuration without duplicating resource definitions.
- `check` blocks: post-apply assertions (Terraform 1.5+) verify ALB DNS and ECR URL are non-empty
  after apply — catches partial failures that don't error at the resource level.
- VPC endpoints for ECR, Secrets Manager, and CloudWatch Logs: eliminates NAT Gateway charges for
  AWS-internal API traffic, which is the largest hidden cost in Fargate deployments.
- Dual auto-scaling policies (CPU + ALBRequestCountPerTarget): CPU handles compute-bound load,
  request count handles I/O-bound spikes typical of WebSocket/chat workloads.

### OpenTofu

HashiCorp changed the Terraform license to BSL in 2023. OpenTofu is the CNCF-hosted open-source fork
with identical HCL syntax. Enterprise adoption is growing; all HCL in this skeleton is compatible
with OpenTofu without modification.

### DevSecOps tooling

Terraform-specific security and quality tooling is split between pre-commit (fast, shift-left) and
CI (heavier analysis, controlled environment):

**Pre-commit (`antonbabenko/pre-commit-terraform`):**

`terraform_fmt` runs `terraform fmt` on staged `.tf` files at commit time. HCL formatting is
enforced at the same layer as Python formatting (ruff-format) — malformed HCL never enters the repo.
Requires `terraform` on the developer's PATH, which is already a prerequisite for working with the
codebase.

**Pre-commit (`gitleaks`):**

Gitleaks scans all staged files for secrets patterns before they enter the repo. Catches API keys,
connection strings, and private keys that accidentally appear in `.tf` files, `.tfvars`, or anywhere
else in the tree. Applied repo-wide, not just to Terraform — a single hook covers all languages and
file types.

**CI — TFLint (`terraform-security` job):**

TFLint runs `--recursive` from the `terraform/` directory with the AWS ruleset plugin enabled
(`terraform/.tflint.hcl`). The AWS plugin adds ~100+ rules beyond basic HCL syntax: deprecated
resource arguments, invalid instance types, missing required attributes.
`--minimum-failure-severity=error` fails the job on errors only, allowing warnings to surface
without blocking PRs. TFLint plugins are cached keyed on `.tflint.hcl` to avoid re-downloading the
AWS ruleset on every run.

**CI — Trivy IaC scan (`terraform-security` job):**

Trivy replaced the deprecated `tfsec` tool in 2023 and is now the standard for IaC security
scanning. It checks Terraform for security misconfigurations: overly permissive security groups,
unencrypted storage, missing logging, public accessibility on resources that should be private. The
scan fails on `HIGH` and `CRITICAL` severity findings only — `LOW` and `MEDIUM` surface as warnings
to allow informed triage without blocking every PR. The `terraform-security` job runs in parallel
with the `ci` job; both must pass before merge.

**What is not scanned:**

`terraform validate` is not wired to pre-commit because it requires `terraform init` with a valid
backend, which is impractical for the partial backend config used here. Validate runs manually and
is enforced by convention. Infracost (cloud cost estimation) is a useful addition for production PRs
but requires an API key and organizational context; not added here.

### Known limitations and scaling path

This skeleton is intentionally scoped to what a single-team deployment needs on day one. The
following shortcomings are real; each has a documented mitigation path.

**Relative module paths, no module registry**

All `source = "../../modules/..."` paths tightly couple environments to the monorepo layout. Works
fine for a single repo today. As the platform grows (multiple services sharing the same
networking/ECS patterns), the modules should be versioned, tagged, and published to a private
Terraform module registry (Terraform Cloud, or a git tag reference like
`source = "git::ssh://github.com/org/tf-modules.git//networking?ref=v1.4.0"`). This decouples module
versions from application deploys and enables independent module upgrades.

**RDS master password in Terraform state**

`random_password.db.result` is stored in state. The state bucket is KMS-encrypted and access-
controlled, so the risk is contained, but anyone with state read access can extract the plaintext
password. The modern mitigation is `manage_master_user_password = true` on `aws_db_instance`, which
delegates credential storage and rotation entirely to Secrets Manager — Terraform never sees the
password. Migration path: add `manage_master_user_password = true`, import the new secret ARN, and
remove the `random_password` and `aws_secretsmanager_secret` resources via a `moved` block + import.

**No secret rotation**

`aws_secretsmanager_secret_rotation` is not configured. Compliance environments (SOC 2, PCI-DSS,
HIPAA) require automated rotation with a documented rotation period. Mitigation: add a rotation
Lambda (AWS provides a managed rotation function for RDS) and wire it to the secret via
`aws_secretsmanager_secret_rotation`. If adopting `manage_master_user_password` above, RDS handles
rotation natively without a Lambda.

**No Route 53 / DNS wiring**

The ALB outputs a DNS name but no `aws_route53_record` is created; DNS is a manual post-apply step.
Mitigation: add an `aws_route53_record` in the ALB module (or a dedicated `dns` module) pointing to
the ALB alias. This also unblocks ACM DNS validation automation. Deliberately omitted here because
hosted zone IDs are account-specific and would have required hard-coded placeholders.

**No WAF**

No `aws_wafv2_web_acl` is associated with the ALB. Required for production workloads subject to
OWASP Top 10 exposure or compliance requirements. Mitigation: add a `waf` module with an ALB-scoped
WebACL using AWS Managed Rule Groups (AWSManagedRulesCommonRuleSet as a baseline). Separate module
to keep it optional and cost-visible — WAF is billed per rule per million requests.

**No CloudWatch alarms or monitoring module**

The ECS and RDS modules create log groups but no alarms. No SNS topic for paging. In production: ALB
5xx rate, ECS task CPU/memory, RDS connections and IOPS, and auto-scaling activity should all
trigger alarms. Mitigation: add a `monitoring` module that accepts resource names/ARNs as inputs and
creates a CloudWatch dashboard, composite alarm, and SNS topic. Keep it a separate optional module
so dev doesn't pay for CloudWatch alarms it doesn't need.

**No KMS on CloudWatch log groups**

CloudWatch log groups use default AWS-managed encryption. Customer-managed KMS keys are required for
compliance workloads where logs may contain PII. Mitigation: pass a `log_kms_key_arn` variable to
the ECS and RDS modules and wire it to `aws_cloudwatch_log_group.kms_key_id`. Omitted here because
the key ARN is account-specific.

**ECR per environment, not per account**

ECR repositories live inside the ECS module, one per environment. Enterprise pattern is a dedicated
shared ECR account (via AWS Organizations) with cross-account pull permissions granted to each
workload account. This centralizes image scanning, lifecycle policies, and replication
configuration. Mitigation path: extract ECR into its own module with an optional
`cross_account_pull_arns` variable and remove it from the ECS module. Acceptable as-is for a
single-account deployment.

**Environment directories are structural copies**

`dev/`, `staging/`, and `prod/` share identical `main.tf`, `variables.tf`, and `outputs.tf`. Any
structural change must be made in three places. The environment IS the parameter (intentional), but
at scale this becomes a maintenance burden. Two native options in 2026: (a) **Terraform Stacks**
(HCP Terraform) — HashiCorp's first-party answer, using `.tfstack.hcl` + `.tfdeploy.hcl` to deploy
one configuration across multiple environments without duplication, but requires Terraform Cloud/
Enterprise; (b) **Terragrunt** — the long-standing open-source wrapper, a `terragrunt.hcl` with a
single `terraform { source }` block eliminates the structural copies and works with any state
backend. For teams not on HCP Terraform, Terragrunt remains the most widely adopted solution beyond
~4 environments.

**No multi-region failover**

All resources are deployed to a single region specified in `terraform.tfvars`. VPC endpoint service
names are correctly parameterized via `data.aws_region.current.name`, so the modules are
region-agnostic. Active-passive failover would require a second environment directory (e.g.
`environments/prod-eu`), Route 53 health checks, and a Global Accelerator or CloudFront origin
failover policy. Out of scope for a chat backend at this maturity; worth noting before a contractual
SLA is signed.

## Justfile

### just as the task runner

`just` is a command runner (not a build system) — no implicit dependency tracking, no DAG, no
stale-file logic. That makes it predictable: `just dev` always runs dev, `just test` always runs
tests. Makefiles carry GNU Make semantics (targets as files, phony declarations, tab-sensitive
syntax) that add complexity for no benefit in a Python project.

Recipes defined: `dev` (hot-reload via `run.py`), `test` (`pytest -W ignore`), `build` (docker image
tagged `chatty:latest`), `up` (`docker compose up -d --wait`), `down` (`docker compose down -v`).

No `lint` or `typecheck` recipes — pre-commit is the single source of truth for those. Running them
through `just` would duplicate invocation paths and risk drift between local and CI behavior.

______________________________________________________________________

## pip-audit

### Dependency vulnerability scanning in CI

`pip-audit` checks all installed packages against the Python Packaging Advisory Database (PyPA) and
OSV. It runs in the `ci` job after `uv sync`, before tests — a failed audit means a known CVE in the
dependency tree, which should block the build.

Pre-commit is not the right layer for this: `pip-audit` makes network calls to query advisory
databases and operates on the resolved dependency graph, not source files. Running it in CI keeps
the pre-commit hook list fast and offline-capable.

`pip-audit` is added as a dev dependency so it is pinned in `uv.lock` and the CI environment matches
local invocations exactly.

______________________________________________________________________

______________________________________________________________________

## Design decisions (not yet implemented in code)

> The following sections document planned approaches and forward-looking architecture decisions.
> Nothing below this line is implemented in this repository. These sections are here to facilitate
> the technical review conversation and to establish a clear direction for production readiness.

______________________________________________________________________

## CI/CD approach

### Pipeline design

The deployment pipeline is GitHub Actions → ECR → ECS, using ECS native rolling deployments. No
CodeDeploy is involved. The full sequence on merge to `main`:

```
1. GHA ci job         — pre-commit (lint/format/typecheck) + pytest
2. GHA smoke-test     — docker compose up --wait + pytest tests_smoke/
3. GHA terraform-security — TFLint + Trivy IaC scan
4. GHA deploy job     — build image → push to ECR → register task def → update ECS service
                        (deploy job is not yet wired; steps 1–3 are the current CI gate)
```

Steps 1–3 run in parallel where independent. The deploy job runs only after all three pass, keyed on
the `main` branch. PRs run steps 1–3 only; no deployment from feature branches.

### Image tagging

Every image is tagged with the git SHA (`${{ github.sha }}`). ECR repositories have
`image_tag_mutability = "IMMUTABLE"`, so a SHA tag cannot be overwritten. Two practical
consequences:

- A deployment is always traceable to a specific commit.
- Rolling back is re-deploying the previous SHA tag — no special rollback tooling needed.
  `git revert` + merge = new SHA = new image = clean forward rollback.

The `:latest` tag is never used for deployment. It may be pushed as a convenience for local
`docker pull` but is never referenced in the ECS task definition.

### Rolling deploy vs blue/green

ECS native rolling deploy with `deployment_circuit_breaker { rollback = true }` is used rather than
CodeDeploy blue/green. Reasoning:

- This service uses persistent WebSocket connections (socket.io). Blue/green creates a parallel task
  set and shifts ALB traffic via weighted listener rules; existing WebSocket connections are held
  open on the "blue" tasks until drained regardless of deployment strategy — but blue/green's
  additional ALB listener on a test port (8080) and the weighted target group setup add operational
  complexity that does not improve connection draining behavior.
- The circuit breaker provides the key safety property: if new tasks fail their `/health/ready`
  health check within the deployment window, ECS automatically rolls back to the previous task
  definition without human intervention.
- `deployment_minimum_healthy_percent = 100` prevents capacity reduction: the new task must be
  healthy before any old task is terminated.
- Blue/green makes sense when a service needs canary testing with real production traffic before
  full cutover (e.g., backwards-incompatible API changes, payment processing). That is not the
  current requirement.

### Rollback

Rolling back is operationally equivalent to a new forward deployment:

```
git revert <bad-sha>  →  merge to main  →  pipeline builds new image  →  ECS rolls to new SHA
```

If the circuit breaker fires mid-deployment, ECS restores the previous task definition automatically
— no manual intervention required. For an urgent hotfix before a revert can be merged, an operator
can manually update the ECS service desired task definition to the previous SHA tag via the AWS
console or `aws ecs update-service`.

### What is not yet wired

The `deploy` GitHub Actions job is documented here but not yet implemented. The Terraform skeleton
provisions all required infrastructure (ECR, ECS cluster, IAM task execution role with ECR pull
permissions). The deploy job would add:

- `aws-actions/configure-aws-credentials@v4` — OIDC-based credentials (no long-lived access keys)
- `aws-actions/amazon-ecr-login@v2` — ECR authentication
- `docker build --tag <ecr-url>:<sha> .` + `docker push`
- `aws-actions/amazon-ecs-render-task-definition@v1` — inject new image into task definition JSON
- `aws-actions/amazon-ecs-deploy-task-definition@v2` — register and deploy; waits for steady state

OIDC credentials (GitHub's identity provider registered as an IAM OIDC provider in the AWS account)
eliminate the need for stored `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets in the GitHub
repository.

______________________________________________________________________

## Exposing the service to the front end

### ALB + CloudFront topology

The ALB is the single ingress point for the backend. CloudFront sits in front of it for production
deployments. The recommended topology:

```
Browser → CloudFront → ALB (HTTPS) → ECS Fargate tasks
```

CloudFront provides:

- **DDoS protection** — AWS Shield Standard is included at no extra cost on every CloudFront
  distribution. Shield Advanced (automatic application-layer mitigation) is available if SLAs
  require it.
- **Edge TLS termination** — ACM certificate attached to the CloudFront distribution; the ALB can
  use a second ACM certificate for origin encryption, or use HTTP internally if the VPC is trusted.
- **HTTP caching** — REST API responses with appropriate `Cache-Control` headers (e.g., GET
  `/messages?room=x`) can be cached at the edge, reducing origin load.
- **Geo-restriction and WAF** — WAF WebACL can be attached to the CloudFront distribution as an
  alternative (or in addition) to an ALB-level WAF.

CloudFront has supported WebSocket proxying since 2018. WebSocket upgrade requests
(`Upgrade: websocket`) are forwarded to the origin as-is; CloudFront does not buffer or cache
WebSocket frames. A dedicated CloudFront cache behavior with `Allowed HTTP Methods: GET, HEAD` and
`Cache Policy: CachingDisabled` should be set for the WebSocket path (`/socket.io/*`) to prevent any
cache interference.

### WebSocket routing

The socket.io server mounts at `/socket.io/`. The ALB listener rule routes all traffic to the single
ECS target group (target type `ip`, port 8000). No path-based routing split is needed between HTTP
and WebSocket — uvicorn handles both on the same port via `socketio_app` (the ASGI wrapper that
intercepts the WebSocket upgrade before FastAPI middleware).

Connection draining (`deregistration_delay` on the target group, default 300 seconds) gives existing
WebSocket connections time to close gracefully when a task is deregistered during a rolling deploy
or scale-in event. For a chat application, 300 seconds is a reasonable default; reduce it if deploys
need to complete faster and the client reconnects cleanly.

### Custom domain

Route 53 → CloudFront alias record (`A` + `AAAA`). The CloudFront distribution uses an ACM
certificate in `us-east-1` (required for CloudFront regardless of the origin region). The ALB uses a
regional ACM certificate. Both are provisioned separately from Terraform because ACM DNS validation
requires a hosted zone ID that is account-specific.

______________________________________________________________________

## Auto scaling and load testing

### ECS target tracking policies

Two auto-scaling policies are wired in the ECS module:

- **CPU utilization — target 70%.** Handles compute-bound load (request parsing, DB queries,
  business logic). At 70% the scaler has headroom to absorb a traffic spike before the next task
  comes online (typically 60–90 seconds for ECS Fargate cold start).
- **ALBRequestCountPerTarget — target 1,000.** Handles I/O-bound load typical of WebSocket
  workloads: each connected socket counts as an open request from the ALB's perspective but consumes
  little CPU. Without a request-count policy, CPU-based scaling would under-provision during
  high-connection, low-CPU periods.

The targets (70% CPU, 1,000 requests) are starting points. They should be validated and tuned after
a load test baseline is established.

### Locust baseline approach

[Locust](https://locust.io) is the recommended load testing tool: Python-based, scriptable, and
capable of testing both HTTP endpoints and WebSocket connections via the
[locust-plugins](https://github.com/SvAnd/locust-plugins) `SocketIoUser` class.

Baseline load test scenarios:

1. **Ramp HTTP endpoints** — Gradually increase concurrent users hitting `GET /ready`,
   `GET /health/`, and any REST endpoints. Identify the request rate at which CPU hits 70% on a
   single task. Validate that ECS scales out before p99 latency degrades.
1. **WebSocket connection flood** — Open a large number of persistent socket.io connections, send
   periodic `message` events, and verify that the ALBRequestCountPerTarget policy scales out
   correctly without CPU climbing.
1. **Mixed load** — HTTP + WebSocket simultaneously, simulating real usage.

Locust results feed directly into scaling policy target refinement. Run load tests against the
staging environment (RDS enabled, same task sizing as prod) before setting prod tfvars.

### Scale-in conservatism

The default scale-in cooldown (300 seconds) is intentionally conservative for a chat workload.
Scaling in too aggressively terminates tasks that still hold open WebSocket connections, forcing
client reconnects and causing a visible disruption. The `deregistration_delay` on the ALB target
group governs how long ECS waits for connections to drain before terminating a task; both parameters
should be tuned together.

______________________________________________________________________

## Cloud spend management

### Tagging strategy

Every resource created by Terraform inherits three tags via `provider.default_tags`:

```hcl
Project     = var.project      # "chatty"
Environment = var.environment  # "dev" | "staging" | "prod"
ManagedBy   = "terraform"
```

AWS Cost Explorer can slice spend by any tag. Enabling tag-based cost allocation in the AWS Billing
console makes per-environment and per-project cost breakdowns available within 24 hours. The
`ManagedBy = "terraform"` tag also makes it easy to identify unmanaged (manual or drift) resources.

### VPC endpoint savings

The most significant hidden cost in Fargate deployments is NAT Gateway data processing charges
($0.045/GB). Every ECR image pull, Secrets Manager API call, and CloudWatch Logs shipment traverses
the NAT Gateway without VPC endpoints. The five VPC endpoints provisioned in the networking module
(S3 Gateway, ECR API, ECR DKR, Secrets Manager, CloudWatch Logs) route AWS-internal traffic on the
AWS backbone, bypassing the NAT Gateway entirely. Interface endpoints cost $0.01/hour + $0.01/GB —
materially cheaper than NAT for high-frequency AWS API calls.

### Per-environment cost controls

- **Dev** — `single_nat_gateway = true` saves ~$30/month (one NAT Gateway vs one per AZ).
  `create_rds = false` saves ~$25–50/month depending on instance class. Minimum ECS task sizing (256
  CPU, 512 MB) minimizes Fargate compute costs.
- **Staging** — RDS enabled at `db.t4g.small`; smaller than prod but functionally equivalent. Single
  NAT (two AZs).
- **Prod** — Multi-AZ NAT and Multi-AZ RDS are deliberate spend for HA. Cost is justified by the
  SLA; the sizing is documented in `terraform.tfvars` so it is visible in code review.

### Savings Plans and Reserved Instances

After 3+ months of stable production usage:

- **Compute Savings Plans (1-year, no upfront)** — reduce Fargate vCPU and memory charges by ~20–30%
  vs on-demand with no commitment to specific instance families. Applies automatically across ECS
  Fargate and Lambda.
- **RDS Reserved Instances (1-year, no upfront)** — reduce RDS instance-hours by ~40% vs on-demand.
  Lock in after the instance class is validated by production load.

### Additional cost controls not yet in Terraform

- **ECR lifecycle policy** — purge untagged images automatically. Each Docker build layer push
  leaves untagged images that accumulate storage charges silently. A lifecycle rule
  (`untaggedStatus = "expired"` after 1 day) keeps the repository clean.
- **CloudWatch log retention** — log groups without a retention policy store logs indefinitely. A
  30-day retention for dev/staging and 90-day for prod is a reasonable starting point; critical logs
  should be exported to S3 + Glacier for long-term compliance archival at lower cost.

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
