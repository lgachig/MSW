# MSW Digitize API

Lightweight FastAPI service for turning a user-selected song image into validated
song JSON. The API key stays on the server. OpenAI Responses API and Google Gemini
are supported; select the provider with `AI_PROVIDER`.

## Run locally

```sh
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
cp .env.example .env  # skip this if backend/.env already exists; it preserves your keys
# Edit .env and set AI_PROVIDER=gemini and GEMINI_API_KEY on this machine only.
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Health check: `GET /health`. Digitization: `POST /digitize` with a multipart
field named `image` containing a JPEG, PNG, or WebP file. Images are held in
memory for the request and are not written to disk. OpenAI requests set
`store: false`; image data is still sent to the selected provider for processing.

The service limits image size (10 MiB by default), validates MIME type and file
signature, validates the returned JSON with Pydantic, retries one invalid model
result, and responds with safe error messages. A SQLite counter limits requests
per UTC day and client IP; only a hash of the IP is stored. Behind a reverse
proxy, configure the proxy to supply a trustworthy client address before
production. This per-IP quota is an MVP abuse-control measure, not strong user
authentication, and can be bypassed by rotating IP addresses.

Choose `AI_PROVIDER=gemini` or `AI_PROVIDER=openai`. For Gemini, set
`GEMINI_API_KEYS` to a comma-separated list of keys (or `GEMINI_API_KEY` for one
key) and optionally `GEMINI_MODEL` (defaults to `gemini-3.8-flash`). The service
tries the next key when Gemini rejects a key or reports exhausted quota (401,
403, or 429), and starts the next request with the next key in the list.
For OpenAI, set `OPENAI_API_KEY` and optionally `OPENAI_MODEL`. Also configurable:
`DAILY_REQUEST_LIMIT`, `MAX_IMAGE_BYTES`, and `QUOTA_DATABASE_PATH`. Never put a
provider key in Flutter, the repository, logs, or an API response.

## Check the server

From the repository root:

```sh
cd backend
source .venv/bin/activate
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

In another terminal, check health and open the interactive API page:

```sh
curl http://127.0.0.1:8000/health
```

Expected health response: `{"status":"ok"}`. Open
`http://127.0.0.1:8000/docs` to check the API documentation. To verify an actual
Gemini request, send a real song image (the request uses quota and may incur
provider usage):

```sh
curl -X POST http://127.0.0.1:8000/digitize \
  -F "image=@/absolute/path/to/song.jpg;type=image/jpeg"
```

A successful request returns JSON with `title`, `key`, and `sections`. HTTP 503
means the selected provider key is missing; HTTP 502 means the model request or
its response failed. The health endpoint only confirms the server is running; it
does not call Gemini.

## Flutter client

Configure the service URL at build time, for example:

```sh
flutter run --dart-define=MSW_DIGITIZE_API_URL=https://your-api.example
```

For a physical iPhone, use the reachable HTTPS URL of the server. Do not use
`localhost` from the phone. The app includes no provider key. If the URL is not
configured, the AI action reports that setting rather than sending the image.

## Tests

```sh
python3 -m unittest discover -s tests -v
# or: pytest
```

The tests use a fake model provider and do not send images to OpenAI or require
an API key.
