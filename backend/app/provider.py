import base64
from typing import Protocol

import httpx


OUTPUT_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": ["title", "key", "sections"],
    "properties": {
        "title": {"type": ["string", "null"]},
        "key": {"type": ["string", "null"]},
        "sections": {
            "type": "array",
            "items": {
                "type": "object",
                "additionalProperties": False,
                "required": ["name", "lines"],
                "properties": {
                    "name": {"type": "string"},
                    "lines": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "additionalProperties": False,
                            "required": ["text", "chords"],
                            "properties": {
                                "text": {"type": "string"},
                                "chords": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "additionalProperties": False,
                                        "required": ["chord", "position"],
                                        "properties": {
                                            "chord": {"type": "string"},
                                            "position": {"type": "integer"},
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    },
}


def _gemini_schema(schema: dict) -> dict:
    """Keep only schema fields accepted by Gemini's structured output API."""
    def clean(value):
        if isinstance(value, dict):
            cleaned = {
                key: clean(child)
                for key, child in value.items()
                if key not in {"additionalProperties", "type"}
            }
            schema_type = value.get("type")
            if isinstance(schema_type, list):
                non_null_types = [item for item in schema_type if item != "null"]
                if len(non_null_types) != 1:
                    raise ValueError("Gemini schema fields must have one non-null type.")
                cleaned["type"] = non_null_types[0]
                cleaned["nullable"] = "null" in schema_type
            elif schema_type is not None:
                cleaned["type"] = schema_type
            return cleaned
        if isinstance(value, list):
            return [clean(item) for item in value]
        return value

    return clean(schema)


class SongDigitizer(Protocol):
    async def generate(
        self, image: bytes, mime_type: str, correction: str | None = None
    ) -> str: ...


class OpenAISongDigitizer:
    def __init__(self, api_key: str, model: str, timeout_seconds: float = 120):
        self._api_key = api_key
        self._model = model
        self._timeout_seconds = timeout_seconds

    async def generate(
        self, image: bytes, mime_type: str, correction: str | None = None
    ) -> str:
        if not self._api_key:
            raise RuntimeError("The server model API key is not configured.")

        prompt = (
            "Read this song sheet. Return only the requested JSON. Preserve the visible "
            "lyrics and chord names. Each chord position is its zero-based character "
            "column above the lyric line. Keep line order and group lines into visible "
            "sections. If a title or key is not visible, use null. Never invent text or chords."
        )
        if correction:
            prompt += f" Correct the previous result to satisfy the schema: {correction}"

        encoded_image = base64.b64encode(image).decode("ascii")
        payload = {
            "model": self._model,
            "input": [
                {
                    "role": "user",
                    "content": [
                        {"type": "input_text", "text": prompt},
                        {
                            "type": "input_image",
                            "image_url": f"data:{mime_type};base64,{encoded_image}",
                            "detail": "high",
                        },
                    ],
                }
            ],
            "text": {
                "format": {
                    "type": "json_schema",
                    "name": "song_digitization",
                    "strict": True,
                    "schema": OUTPUT_SCHEMA,
                }
            },
            "max_output_tokens": 8000,
            "store": False,
        }

        async with httpx.AsyncClient(timeout=self._timeout_seconds) as client:
            response = await client.post(
                "https://api.openai.com/v1/responses",
                headers={"Authorization": f"Bearer {self._api_key}"},
                json=payload,
            )
            response.raise_for_status()

        result = response.json()
        if result.get("status") == "incomplete":
            raise ValueError("The model returned an incomplete result.")
        for item in result.get("output", []):
            if item.get("type") != "message":
                continue
            for part in item.get("content", []):
                if part.get("type") == "refusal":
                    raise ValueError("The model refused the image request.")
                if part.get("type") == "output_text":
                    return part["text"]
        raise ValueError("The model returned no structured text.")


class GeminiSongDigitizer:
    def __init__(self, api_keys: str | list[str] | tuple[str, ...], model: str, timeout_seconds: float = 120):
        if isinstance(api_keys, str):
            api_keys = [api_keys]
        self._api_keys = [key.strip() for key in api_keys if key.strip()]
        self._model = model
        self._timeout_seconds = timeout_seconds
        self._next_key = 0

    async def generate(
        self, image: bytes, mime_type: str, correction: str | None = None
    ) -> str:
        if not self._api_keys:
            raise RuntimeError("The server model API key is not configured.")

        prompt = (
            "Read this song sheet. Return only the requested JSON. Preserve the visible "
            "lyrics and chord names. Each chord position is its zero-based character "
            "column above the lyric line. Keep line order and group lines into visible "
            "sections. If a title or key is not visible, use null. Never invent text or chords."
        )
        if correction:
            prompt += f" Correct the previous result to satisfy the schema: {correction}"

        payload = {
            "contents": [{
                "role": "user",
                "parts": [
                    {"text": prompt},
                    {"inline_data": {
                        "mime_type": mime_type,
                        "data": base64.b64encode(image).decode("ascii"),
                    }},
                ],
            }],
            "generationConfig": {
                "responseMimeType": "application/json",
                "responseSchema": _gemini_schema(OUTPUT_SCHEMA),
                "maxOutputTokens": 8000,
            },
        }
        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{self._model}:generateContent"
        )

        def safe_error_message(response: httpx.Response) -> str:
            try:
                message = str(response.json().get("error", {}).get("message", ""))
            except (ValueError, AttributeError):
                message = ""
            for secret in self._api_keys:
                if secret:
                    message = message.replace(secret, "[redacted]")
            return message[:500] or "No provider error message was returned."

        last_error: httpx.HTTPStatusError | None = None
        async with httpx.AsyncClient(timeout=self._timeout_seconds) as client:
            for attempt in range(len(self._api_keys)):
                key_index = (self._next_key + attempt) % len(self._api_keys)
                response = await client.post(
                    url,
                    headers={"x-goog-api-key": self._api_keys[key_index]},
                    json=payload,
                )
                if response.is_success:
                    self._next_key = (key_index + 1) % len(self._api_keys)
                    break
                message = safe_error_message(response)
                key_error = response.status_code == 400 and any(
                    term in message.lower() for term in ("api key", "api_key", "key not valid")
                )
                retryable_status = response.status_code in {401, 403, 429, 500, 502, 503, 504}
                if not retryable_status and not key_error:
                    raise RuntimeError(f"Gemini HTTP {response.status_code}: {message}")
                last_error = httpx.HTTPStatusError(
                    f"Gemini HTTP {response.status_code}: {message}",
                    request=response.request,
                    response=response,
                )
            else:
                assert last_error is not None
                raise last_error

        result = response.json()
        candidates = result.get("candidates", [])
        if not candidates:
            raise ValueError("The model returned no candidates.")
        parts = candidates[0].get("content", {}).get("parts", [])
        for part in parts:
            if "text" in part:
                return part["text"]
        raise ValueError("The model returned no structured text.")
