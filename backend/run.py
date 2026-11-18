"""Entry point: python run.py"""
import os

import uvicorn

from app import config

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host=config.HOST,
        port=config.PORT,
        reload=bool(os.environ.get("KLINISIA_RELOAD")),
        log_level="info",
    )
