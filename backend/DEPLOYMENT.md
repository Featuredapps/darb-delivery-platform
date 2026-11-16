# Backend deployment and local secure setup

## Prepare secrets
Copy `.env.example` to `.env` and replace every placeholder. Generate separate values with `openssl rand -hex 32`. Use different values for PostgreSQL, Redis, JWT access, JWT refresh, and OTP secrets. Never commit the real `.env`.

## Local stack
From `backend/`:

```sh
cp .env.example .env
# Edit .env and replace every placeholder
docker compose up --build
```

Database, Redis, and API ports bind to localhost only. PostgreSQL/PostGIS and Redis are isolated on the internal Docker network. The one-shot migration service waits for PostgreSQL health; API startup waits for successful migrations and healthy Redis.

Health check: `http://127.0.0.1:3000/healthz`.

## Production requirements
- Set `NODE_ENV=production`; use strong, distinct JWT and OTP secrets.
- Configure the actual SMS provider HTTPS endpoint and API key. The current generic HTTP payload is `{ "to": "+963...", "message": "..." }`; adapt it to the provider's documented API before real OTP delivery.
- Production startup fails if SMS credentials or core secrets are missing. Console SMS refuses to send in production.
- Terminate HTTPS at a trusted proxy/load balancer. Set `CORS_ORIGINS` to exact browser origins; native mobile clients usually omit Origin.
- Run migrations as a release step, not in every API replica. Back up PostgreSQL and test restoration before accepting real orders.
- Do not expose PostgreSQL or Redis publicly. Use private networking, TLS, access controls, monitoring, and tested backups.

## Android build
```sh
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_API_HOST/api/v1
```

There is no emulator-address fallback. A missing or malformed API URL fails clearly; HTTPS is required by default. Do not enable cleartext traffic in production.

## Limitations
The SMS integration is a generic adapter, not a verified Syrian carrier integration. A successful build is not production readiness. End-to-end role/order tests, authorization review, refresh-token revocation/rotation review, backup/restore drills, and a signed Android release keystore remain required.
