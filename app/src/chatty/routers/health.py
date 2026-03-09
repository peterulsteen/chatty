"""
Health check endpoints.
"""

from datetime import UTC, datetime

from fastapi import APIRouter, Response
from pydantic import BaseModel
from sqlalchemy import text

from chatty.core.database import SessionLocal

router = APIRouter()


class HealthResponse(BaseModel):
    """Health check response model."""

    status: str
    timestamp: datetime
    version: str


class ReadyResponse(BaseModel):
    """Readiness check response model."""

    status: str
    checks: dict[str, str]


@router.get("/ready", response_model=ReadyResponse)
async def ready(response: Response) -> ReadyResponse:
    """
    Readiness check endpoint.

    Returns ok when the API is ready to serve traffic.
    Returns 503 with status degraded if any dependency is unavailable.
    """
    checks: dict[str, str] = {"api": "ok"}

    try:
        db = SessionLocal()
        try:
            db.execute(text("SELECT 1"))
            checks["db"] = "ok"
        finally:
            db.close()
    except Exception:
        checks["db"] = "error"

    overall = "ok" if all(v == "ok" for v in checks.values()) else "degraded"
    if overall != "ok":
        response.status_code = 503

    return ReadyResponse(status=overall, checks=checks)


@router.get("/", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    """
    Health check endpoint.

    Returns the current health status of the application.
    """
    return HealthResponse(
        status="healthy",
        timestamp=datetime.now(UTC),
        version="0.1.0",
    )
