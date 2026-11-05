import unittest
from unittest.mock import patch

import httpx

from app.provider import GeminiSongDigitizer, _gemini_schema


class FakeAsyncClient:
    responses: list[httpx.Response] = []
    calls: list[dict] = []

    def __init__(self, *args, **kwargs):
        pass

    async def __aenter__(self):
        type(self).calls = []
        return self

    async def __aexit__(self, *args):
        return None

    async def post(self, url, headers, json):
        type(self).calls.append({"url": url, "headers": headers, "json": json})
        return type(self).responses.pop(0)


def response(status: int, body: dict) -> httpx.Response:
    request = httpx.Request("POST", "https://generativelanguage.googleapis.com/test")
    return httpx.Response(status, json=body, request=request)


class GeminiProviderTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        FakeAsyncClient.responses = []
        FakeAsyncClient.calls = []

    async def test_uses_next_key_after_quota_error_and_sends_supported_schema(self):
        FakeAsyncClient.responses = [
            response(429, {"error": {"message": "quota exceeded"}}),
            response(200, {"candidates": [{"content": {"parts": [{"text": "{}"}]}}]}),
        ]
        provider = GeminiSongDigitizer(["first-test-key", "second-test-key"], "test-model")

        with patch("app.provider.httpx.AsyncClient", FakeAsyncClient):
            result = await provider.generate(b"image", "image/png")

        self.assertEqual(result, "{}")
        self.assertEqual(
            [call["headers"]["x-goog-api-key"] for call in FakeAsyncClient.calls],
            ["first-test-key", "second-test-key"],
        )
        schema = FakeAsyncClient.calls[-1]["json"]["generationConfig"]["responseSchema"]
        self.assertNotIn("additionalProperties", schema)
        self.assertNotIn("additionalProperties", schema["properties"]["sections"]["items"])

    async def test_does_not_rotate_keys_for_schema_request_errors(self):
        FakeAsyncClient.responses = [
            response(400, {"error": {"message": "Invalid response schema"}}),
            response(200, {"candidates": [{"content": {"parts": [{"text": "{}"}]}}]}),
        ]
        provider = GeminiSongDigitizer(["first-test-key", "second-test-key"], "test-model")

        with patch("app.provider.httpx.AsyncClient", FakeAsyncClient):
            with self.assertRaisesRegex(RuntimeError, "Invalid response schema"):
                await provider.generate(b"image", "image/png")

        self.assertEqual(len(FakeAsyncClient.calls), 1)

    def test_converts_nullable_json_schema_types_for_gemini(self):
        schema = _gemini_schema({"type": "object", "properties": {
            "title": {"type": ["string", "null"]},
        }})

        self.assertEqual(schema["properties"]["title"], {"type": "string", "nullable": True})


if __name__ == "__main__":
    unittest.main()
