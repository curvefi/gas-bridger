from pathlib import Path

from pydantic_settings import BaseSettings

BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    DEBUG: bool = False
    DEV: bool = False

    WEB3_PK: str
    WEB3_PROVIDER_URL: str


settings = Settings()
