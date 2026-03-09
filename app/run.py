"""
Script to run the FastAPI application.
"""

import uvicorn

from chatty.config import settings

if __name__ == "__main__":
    uvicorn.run(
        "chatty.main:socketio_app",
        host=settings.HOST,
        port=settings.PORT,
        reload=True,
    )
