# US API Gateway

Lightweight Go gateway for `api-us.benjoe.top`. Gemini requests originate from
the US node; document and URL extraction are streamed to the Warsaw service.
The gateway has no non-standard Go dependencies and does not install document
conversion tools on the US VPS.

## Routes

- `GET /api/health`
- `POST /api/gemini/generate`
- `POST /api/url-to-text`
- `POST /api/convert-to-text`
- `POST /api/dialogize`

All POST routes require `X-Piraeus-Token`. Gemini generation calls only the
selected non-Lite model and never retries automatically. HTTP failures return
immediately. Small requests time out after 30 seconds; larger payloads retain a
90-second limit.

## Environment

The systemd unit reads `/etc/piraeus-gemini-test.env`:

```dotenv
PORT=3270
PIRAEUS_PROXY_TOKEN=
GEMINI_API_KEY=
WARSAW_PROXY_TOKEN=
WARSAW_BASE_URL=https://api.zionpi.serv00.net
DIALOGIZE_MODEL=gemini-3.6-flash
```

Never commit the populated environment file. Build and deploy the binary with:

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags='-s -w' -o gemini-proxy-test main.go
```
