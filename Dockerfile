# Stage 1: builder
FROM python:3.11-slim AS builder

# Pin uv to the same version used by the uv-lock pre-commit hook
# Ideally this and all other image tags will eventually be pinned to image digest SHA
# once RenovateBot or similar is automating dependency updates
COPY --from=ghcr.io/astral-sh/uv:0.10.9 /uv /uvx /bin/

WORKDIR /app
COPY app/pyproject.toml app/uv.lock ./

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

# Install dependencies only — source is mounted separately via PYTHONPATH
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project --project /app

# Stage 2: final
FROM python:3.11-slim AS final

RUN useradd --uid 1001 --no-create-home --shell /sbin/nologin appuser

COPY --from=builder /app/.venv /app/.venv
COPY app/src/ /app/src/
COPY app/run.py /app/

ENV PYTHONPATH="/app/src" \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app
USER appuser

CMD ["uvicorn", "chatty.main:socketio_app", "--host", "0.0.0.0", "--port", "8000"]
