# Default: list available recipes
default:
    @just --list

# Run the app locally with hot reload
dev:
    cd app && uv run python run.py

# Run the test suite
test:
    cd app && uv run pytest -W ignore

# Build the Docker image
build:
    docker build -t chatty:latest .

# Start the full stack (app + Postgres) and wait for health
up:
    docker compose up -d --wait

# Tear down the stack and remove volumes
down:
    docker compose down -v
