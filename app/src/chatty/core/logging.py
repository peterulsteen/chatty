"""
Logging configuration and utilities.
"""
import logging
import sys
from typing import Any, Dict

import structlog
from structlog.stdlib import LoggerFactory


def configure_logging() -> None:
    """Configure structured logging for the application."""
    # Configure structlog
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer()
        ],
        wrapper_class=structlog.make_filtering_bound_logger(
            logging.INFO if _is_production() else logging.DEBUG
        ),
        logger_factory=LoggerFactory(),
        cache_logger_on_first_use=True,
    )
    
    # Configure standard library logging
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=logging.INFO if _is_production() else logging.DEBUG,
    )
    
    # Set specific logger levels
    logging.getLogger("uvicorn.access").setLevel(
        logging.INFO if _is_production() else logging.DEBUG
    )
    logging.getLogger("uvicorn.error").setLevel(logging.INFO)


def _is_production() -> bool:
    """Check if running in production environment."""
    # You can modify this to check environment variables or other indicators
    return False


def get_logger(name: str) -> structlog.BoundLogger:
    """Get a structured logger instance."""
    return structlog.get_logger(name)


def log_request_info(
    method: str,
    path: str,
    headers: Dict[str, str],
    query_params: Dict[str, Any],
    client_ip: str,
    user_agent: str,
) -> None:
    """Log request information."""
    logger = get_logger("http.request")
    logger.info(
        "Incoming request",
        method=method,
        path=path,
        client_ip=client_ip,
        user_agent=user_agent,
        query_params=query_params,
        headers=_sanitize_headers(headers),
    )


def log_response_info(
    method: str,
    path: str,
    status_code: int,
    response_time_ms: float,
    client_ip: str,
) -> None:
    """Log response information."""
    logger = get_logger("http.response")
    logger.info(
        "Response sent",
        method=method,
        path=path,
        status_code=status_code,
        response_time_ms=round(response_time_ms, 2),
        client_ip=client_ip,
    )


def log_error(
    method: str,
    path: str,
    status_code: int,
    error_message: str,
    exception: Exception | None = None,
    client_ip: str | None = None,
) -> None:
    """Log error information."""
    logger = get_logger("http.error")
    log_data = {
        "method": method,
        "path": path,
        "status_code": status_code,
        "error_message": error_message,
        "client_ip": client_ip,
    }
    
    if exception:
        log_data["exception_type"] = type(exception).__name__
        log_data["exception"] = str(exception)
    
    logger.error("Request error occurred", **log_data)


def _sanitize_headers(headers: Dict[str, str]) -> Dict[str, str]:
    """Remove sensitive headers from logging."""
    sensitive_headers = {
        "authorization",
        "cookie",
        "x-api-key",
        "x-auth-token",
    }
    
    sanitized = {}
    for key, value in headers.items():
        if key.lower() in sensitive_headers:
            sanitized[key] = "[REDACTED]"
        else:
            sanitized[key] = value
    
    return sanitized
