# Backend deployment and local secure setup

## Repository layout

The original backend and Android sources remain in `DARB-source.zip`. Versioned backend patches, health checks, and Prisma migrations live in the repository under `backend/`. The deployment build extracts the archive, then overlays the current backend source patches and migration history before compiling.

## Database migrations

The repository contains the reviewed initial Prisma migration at `backend/prisma/migrations/20261116162000_initial/`. It creates the application schema, enables PostGIS, adds spatial GiST indexes, and enforces the Syrian mobile-number format.

The initial migration was applied successfully in CI to a disposable PostgreSQL 16/PostGIS database using `prisma migrate deploy`. Backend CI applies the committed migration to a fresh PostGIS service before building and running tests.

For local development, extract `DARB-source.zip`, copy the repository's `backend/prisma/migrations/` directory into the extracted backend, set `DATABASE_URL`, then run:

```sh
npx prisma generate
npx prisma migrate deploy
```

Do not use `prisma db push` as a production migration strategy. Review and commit every future schema change as a new migration. Do not edit an already-applied migration; create a follow-up migration instead.

## Prepare secrets

Copy `.env.example` to `.env` for local development and replace every placeholder. Generate separate values for PostgreSQL, Redis, JWT access, JWT refresh, and OTP secrets. Never commit a real `.env`. Keep the initial administrator phone operator-controlled.

## Local stack

Extract `DARB-source.zip`, then run Docker Compose from the extracted `darb-project/backend/` directory. The Compose file starts PostgreSQL/PostGIS, Redis, and the API on local ports. Ensure the migration directory from the repository is copied into the extracted backend before starting the API.

## Health endpoints

- Liveness: `GET /api/v1/healthz` — confirms the Node process responds.
- Readiness: `GET /api/v1/readyz` — confirms Redis responds and the PostgreSQL schema has been initialized (checks for the `User` table).

A passing liveness check does not mean the database schema is ready.

## Zero-cost preview deployment

The root `render.yaml` now creates only the Render Free API service. PostgreSQL and Redis are external services to avoid relying on Render Free Postgres (30-day expiry) and ephemeral Render Key Value storage.

See [FREE-DEPLOYMENT.md](../FREE-DEPLOYMENT.md) for the exact setup using:
- Render Free Web Service for the NestJS API (Frankfurt).
- Supabase Free PostgreSQL (500 MB); enable PostGIS and verify extension schema/search path compatibility before applying migrations.
- Upstash Redis Free (256 MB / 500K commands per month).

The API requires `DATABASE_URL` and `REDIS_URL`. Keep the generated `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, and `OTP_SECRET`. The MsgPlus adapter uses `SMS_PROVIDER=msgplus`, `MSGPLUS_API_KEY`, and the exact approved sender name from the MsgPlus account. For backward compatibility, the sender name is read from `MSGPLUS_SENDER_NAME` first and then `MSGPLUS_SENDER_ID` (despite the legacy variable name, its value must be a name, not a number). It sends template `1` with the account's `P1` variable to `POST https://sms.msgplus.tech/api/v1/send`, using Bearer authentication and `X-Timestamp`. Do not use the legacy `SMS_API_URL` / `SMS_API_KEY` names for this adapter. No live SMS delivery is considered verified until an explicitly approved test is completed; do not send test messages or consume prepaid balance without the service owner's approval.

The free tiers can sleep, pause, or enforce quotas. They are not suitable for real customer data, live orders, payments, or driver dispatch. Do not deploy real users until backups, restore procedures, availability, resource limits, and security have been reviewed.

## Production requirements

- Select durable paid resources with managed database backups and persistent Redis-compatible storage; review pricing before confirming.
- Set `NODE_ENV=production` and use strong, distinct JWT and OTP secrets.
- Configure a real SMS provider that supports delivery to Syrian numbers. The MsgPlus adapter sends `POST /api/v1/send` with `sender_name`, `template_id=1`, `numbers`, and `vars: { P1: <six-digit OTP> }`. This integration is not considered verified until a live test is completed.
- Keep the SMS API URL and key in the hosting provider's secret manager. Console SMS is not suitable for production.
- Terminate HTTPS at the hosting provider's trusted edge. Do not expose PostgreSQL or Redis publicly.
- Back up PostgreSQL and test restoration before accepting real orders. Test role authorization, order lifecycle, OTP rate limits, refresh-token rotation/revocation, and driver tracking.

## Android build

```sh
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_API_HOST/api/v1
```

The API URL must be a real HTTPS endpoint reachable from the device. An emulator address is not a production URL.

## Remaining external integrations

Firebase Cloud Messaging, live maps/geocoding, and a production Syrian SMS provider still require real provider accounts and credentials. A successful CI build does not prove these integrations work.
