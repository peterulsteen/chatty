"""
Application configuration via environment variables (12-factor App).

All config is read from the environment. Defaults are safe for local development.
In production, override via environment variables or a .env file.
"""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    HOST: str = "0.0.0.0"
    PORT: int = 8000
    APP_ENV: str = "development"
    LOG_LEVEL: str = "INFO"
    CORS_ORIGINS: list[str] = ["http://localhost:3000"]
    DATABASE_URL: str = "sqlite:///./chatty.db"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
