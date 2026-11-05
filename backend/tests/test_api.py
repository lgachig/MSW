import json
from pathlib import Path
import tempfile
import unittest

from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.quota import DailyQuota


VALID_RESULT = {
    "title": "Canto de prueba",
    "key": "G",
    "sections": [
        {
            "name": "Verso",
            "lines": [
                {"text": "Tu amor permanece", "chords": [{"chord": "G", "position": 0}]}
            ],
        }
    ],
}
JPEG = b"\xff\xd8\xff" + b"test image bytes"
HEIC = b"\x00\x00\x00\x18ftypheic\x00\x00\x00\x00heic"
HEIF = b"\x00\x00\x00\x18ftypmif1\x00\x00\x00\x00mif1"


class FakeDigitizer:
    def __init__(self, *results: object):
        self.results = list(results)
        self.calls: list[tuple[bytes, str, str | None]] = []

    async def generate(self, image: bytes, mime_type: str, correction: str | None = None) -> str:
        self.calls.append((image, mime_type, correction))
        result = self.results.pop(0)
        return result if isinstance(result, str) else json.dumps(result)


class DigitizeApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        database = str(Path(self.temp_dir.name) / "quota.sqlite3")
        self.settings = Settings(
            openai_api_key="test-key",
            openai_model="test-model",
            daily_request_limit=10,
            max_image_bytes=1024,
            quota_database_path=database,
        )

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def make_client(self, provider: FakeDigitizer, limit: int = 10) -> TestClient:
        quota = DailyQuota(self.settings.quota_database_path, limit)
        return TestClient(create_app(self.settings, provider, quota))

    def test_valid_image_returns_typed_song_json(self) -> None:
        provider = FakeDigitizer(VALID_RESULT)
        with self.make_client(provider) as client:
            response = client.post(
                "/digitize",
                files={"image": ("song.jpg", JPEG, "image/jpeg")},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), VALID_RESULT)
        self.assertEqual(provider.calls[0][0:2], (JPEG, "image/jpeg"))

    def test_real_song_png_is_accepted_by_the_functional_endpoint(self) -> None:
        image_path = (
            Path(__file__).parents[2]
            / "docs"
            / "fotos-prueba"
            / "Screenshot 2026-10-28 at 10.27.24 PM.png"
        )
        image = image_path.read_bytes()
        settings = Settings(
            openai_api_key="test-key",
            openai_model="test-model",
            daily_request_limit=10,
            max_image_bytes=10 * 1024 * 1024,
            quota_database_path=self.settings.quota_database_path,
        )
        provider = FakeDigitizer(VALID_RESULT)
        with TestClient(create_app(settings, provider, DailyQuota(
            settings.quota_database_path, settings.daily_request_limit
        ))) as client:
            response = client.post(
                "/digitize",
                files={"image": (image_path.name, image, "image/png")},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), VALID_RESULT)
        self.assertEqual(provider.calls[0][0:2], (image, "image/png"))

    def test_invalid_model_json_is_retried_once_then_validated(self) -> None:
        provider = FakeDigitizer({"sections": []}, VALID_RESULT)
        with self.make_client(provider) as client:
            response = client.post(
                "/digitize",
                files={"image": ("song.jpg", JPEG, "image/jpeg")},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(provider.calls), 2)
        self.assertIsNotNone(provider.calls[1][2])

    def test_invalid_model_json_after_retry_is_rejected(self) -> None:
        provider = FakeDigitizer({"sections": []}, {"sections": []})
        with self.make_client(provider) as client:
            response = client.post(
                "/digitize",
                files={"image": ("song.jpg", JPEG, "image/jpeg")},
            )

        self.assertEqual(response.status_code, 502)
        self.assertEqual(len(provider.calls), 2)
        self.assertNotIn("test-key", response.text)

    def test_empty_song_content_is_rejected(self) -> None:
        empty_result = {
            "title": None,
            "key": None,
            "sections": [{"name": "Verso", "lines": [{"text": "", "chords": []}]}],
        }
        provider = FakeDigitizer(empty_result, empty_result)
        with self.make_client(provider) as client:
            response = client.post(
                "/digitize",
                files={"image": ("song.jpg", JPEG, "image/jpeg")},
            )
        self.assertEqual(response.status_code, 502)
        self.assertEqual(len(provider.calls), 2)

    def test_unsupported_mime_type_is_rejected(self) -> None:
        provider = FakeDigitizer(VALID_RESULT)
        with self.make_client(provider) as client:
            response = client.post(
                "/digitize",
                files={"image": ("song.txt", b"not an image", "text/plain")},
            )
        self.assertEqual(response.status_code, 415)
        self.assertEqual(provider.calls, [])

    def test_heic_image_is_accepted_and_forwarded_with_its_mime_type(self) -> None:
        provider = FakeDigitizer(VALID_RESULT)
        with self.make_client(provider) as client:
            response = client.post(
                "/digitize",
                files={"image": ("song.heic", HEIC, "image/heic")},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(provider.calls[0][0:2], (HEIC, "image/heic"))

    def test_heif_image_is_accepted_and_forwarded_with_its_mime_type(self) -> None:
        provider = FakeDigitizer(VALID_RESULT)
        with self.make_client(provider) as client:
            response = client.post(
                "/digitize",
                files={"image": ("song.heif", HEIF, "image/heif")},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(provider.calls[0][0:2], (HEIF, "image/heif"))

    def test_openai_configuration_rejects_heic_with_clear_guidance(self) -> None:
        quota = DailyQuota(self.settings.quota_database_path, self.settings.daily_request_limit)
        with TestClient(create_app(self.settings, quota=quota)) as client:
            response = client.post(
                "/digitize",
                files={"image": ("song.heic", HEIC, "image/heic")},
            )

        self.assertEqual(response.status_code, 415)
        self.assertIn("require Gemini", response.json()["detail"])

    def test_mime_type_must_match_the_actual_image(self) -> None:
        provider = FakeDigitizer(VALID_RESULT)
        with self.make_client(provider) as client:
            response = client.post(
                "/digitize",
                files={"image": ("song.png", JPEG, "image/png")},
            )
        self.assertEqual(response.status_code, 415)
        self.assertEqual(provider.calls, [])

    def test_image_size_limit_is_enforced_before_model_call(self) -> None:
        provider = FakeDigitizer(VALID_RESULT)
        large_jpeg = b"\xff\xd8\xff" + b"x" * self.settings.max_image_bytes
        with self.make_client(provider) as client:
            response = client.post(
                "/digitize",
                files={"image": ("song.jpg", large_jpeg, "image/jpeg")},
            )
        self.assertEqual(response.status_code, 413)
        self.assertEqual(provider.calls, [])

    def test_missing_provider_key_disables_digitization_safely(self) -> None:
        settings = Settings(
            openai_api_key="",
            openai_model="test-model",
            daily_request_limit=10,
            max_image_bytes=1024,
            quota_database_path=self.settings.quota_database_path,
        )
        with TestClient(create_app(settings)) as client:
            response = client.post(
                "/digitize",
                files={"image": ("song.jpg", JPEG, "image/jpeg")},
            )
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("OPENAI_API_KEY", response.text)

    def test_per_client_daily_limit_is_enforced(self) -> None:
        provider = FakeDigitizer(VALID_RESULT, VALID_RESULT)
        with self.make_client(provider, limit=1) as client:
            first = client.post("/digitize", files={"image": ("song.jpg", JPEG, "image/jpeg")})
            second = client.post("/digitize", files={"image": ("song.jpg", JPEG, "image/jpeg")})

        self.assertEqual(first.status_code, 200)
        self.assertEqual(second.status_code, 429)
        self.assertEqual(len(provider.calls), 1)


if __name__ == "__main__":
    unittest.main()
