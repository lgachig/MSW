from dataclasses import dataclass
import os

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class Settings:
    openai_api_key: str
    openai_model: str
    daily_request_limit: int
    max_image_bytes: int
    quota_database_path: str
    provider: str = "openai"
    gemini_api_key: str = ""
    gemini_model: str = "gemini-3.5-flash"
    gemini_api_keys: tuple[str, ...] = ()

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            openai_api_key=os.getenv("OPENAI_API_KEY", "").strip(),
            openai_model=os.getenv("OPENAI_MODEL", "gpt-6-luna").strip(),
            daily_request_limit=max(1, int(os.getenv("DAILY_REQUEST_LIMIT", "10"))),
            max_image_bytes=max(1024, int(os.getenv("MAX_IMAGE_BYTES", str(10 * 1024 * 1024)))),
            quota_database_path=os.getenv("QUOTA_DATABASE_PATH", "./data/quotas.sqlite3"),
            provider=os.getenv("AI_PROVIDER", "openai").strip().lower(),
            gemini_api_key=os.getenv("GEMINI_API_KEY", "").strip(),
            gemini_model=os.getenv("GEMINI_MODEL", "gemini-3.5-flash").strip(),
            gemini_api_keys=tuple(
                key.strip()
                for key in os.getenv("GEMINI_API_KEYS", "").replace("\n", ",").split(",")
                if key.strip()
            ),
        )
