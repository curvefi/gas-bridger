from pathlib import Path

from pydantic_settings import BaseSettings

BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    DEBUG: bool = True
    DEV: bool = True


settings = Settings()
