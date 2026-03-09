"""
Health check endpoints.
"""

from datetime import UTC, datetime

from fastapi import APIRouter
from pydantic import BaseModel

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
async def ready() -> ReadyResponse:
    """
    Readiness check endpoint.

    Returns ok when the API is ready to serve traffic.
    """
    return ReadyResponse(status="ok", checks={"api": "ok"})


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
