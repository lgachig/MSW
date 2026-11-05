import logging

from fastapi import FastAPI, File, HTTPException, Request, UploadFile
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from .config import Settings
from .provider import GeminiSongDigitizer, OpenAISongDigitizer, SongDigitizer
from .quota import DailyQuota
from .schemas import DigitizeResponse


ALLOWED_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
}
HEIF_TYPES = {"image/heic", "image/heif"}


def _image_type(data: bytes) -> str | None:
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    if len(data) >= 12 and data[4:8] == b"ftyp":
        brands = {data[8:12]}
        brands.update(data[offset : offset + 4] for offset in range(16, len(data) - 3, 4))
        if brands & {b"heic", b"heix", b"hevc", b"hevx", b"heim", b"heis"}:
            return "image/heic"
        if brands & {b"mif1", b"msf1", b"mif2"}:
            return "image/heif"
    return None


def create_app(
    settings: Settings | None = None,
    provider: SongDigitizer | None = None,
    quota: DailyQuota | None = None,
) -> FastAPI:
    config = settings or Settings.from_env()
    if provider is not None:
        model_provider = provider
    elif config.provider == "gemini":
        gemini_keys = config.gemini_api_keys or config.gemini_api_key
        model_provider = GeminiSongDigitizer(gemini_keys, config.gemini_model)
    elif config.provider == "openai":
        model_provider = OpenAISongDigitizer(config.openai_api_key, config.openai_model)
    else:
        raise ValueError("AI_PROVIDER must be 'openai' or 'gemini'.")
    request_quota = quota or DailyQuota(config.quota_database_path, config.daily_request_limit)
    app = FastAPI(title="MSW Digitize API", version="1.0.0")

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.post("/digitize", response_model=DigitizeResponse)
    async def digitize(request: Request, image: UploadFile = File(...)) -> DigitizeResponse:
        if image.content_type not in ALLOWED_TYPES:
            raise HTTPException(
                status_code=415,
                detail="Use a JPEG, PNG, WebP, HEIC, or HEIF image.",
            )

        data = await image.read(config.max_image_bytes + 1)
        if len(data) > config.max_image_bytes:
            raise HTTPException(status_code=413, detail="Image is larger than the allowed limit.")
        if not data:
            raise HTTPException(status_code=400, detail="The image is empty.")
        mime_type = _image_type(data)
        if mime_type is None or mime_type != image.content_type:
            raise HTTPException(status_code=415, detail="The uploaded file is not a valid supported image.")
        if mime_type in HEIF_TYPES and config.provider != "gemini" and provider is None:
            raise HTTPException(
                status_code=415,
                detail="HEIC and HEIF require Gemini. Choose Gemini or upload a JPEG, PNG, or WebP image.",
            )
        configured_key = (
            (config.gemini_api_keys or (config.gemini_api_key,))
            if config.provider == "gemini"
            else config.openai_api_key
        )
        if not any(configured_key) and provider is None:
            raise HTTPException(status_code=503, detail="Digitization service is not configured.")
        if not request_quota.consume(request.client.host if request.client else None):
            raise HTTPException(status_code=429, detail="Daily digitization limit reached.")

        correction: str | None = None
        for attempt in range(2):
            try:
                raw_result = await model_provider.generate(data, mime_type, correction)
                return DigitizeResponse.model_validate_json(raw_result)
            except ValidationError as error:
                if attempt == 0:
                    correction = str(error)[:1500]
                    continue
                raise HTTPException(
                    status_code=502,
                    detail="The model returned data that does not match the song schema.",
                ) from None
            except HTTPException:
                raise
            except Exception:
                logging.exception("Song digitization provider request failed.")
                raise HTTPException(
                    status_code=502,
                    detail="Could not digitize this image. Please try again.",
                ) from None
        raise HTTPException(status_code=502, detail="Could not digitize this image.")

    @app.exception_handler(HTTPException)
    async def safe_http_errors(request: Request, error: HTTPException) -> JSONResponse:
        return JSONResponse(status_code=error.status_code, content={"detail": error.detail})

    return app


app = create_app()

