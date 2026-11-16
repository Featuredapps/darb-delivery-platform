# Backend deployment and local secure setup

## Repository layout

The original backend and Android sources remain in `DARB-source.zip`. Versioned backend patches, health checks, and Prisma migrations live in the repository under `backend/`. The Render build extracts the archive, then overlays the current backend source patches and migration history before compiling.

## Database migrations

The repository now contains the reviewed initial Prisma migration at `backend/prisma/migrations/20261116162000_initial/`. It creates the application schema, enables PostGIS, adds spatial GiST indexes, and enforces the Syrian mobile-number format.

The initial migration was applied successfully in CI to a disposable PostgreSQL 16/PostGIS database using `prisma migrate deploy`. The normal Backend CI now applies the committed migration to a fresh PostGIS service before building and running tests.

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

## Render test deployment

The root `render.yaml` defines a test deployment in Frankfurt:
- Node API service, PostgreSQL 16, and Redis-compatible Key Value.
- Randomly generated JWT access, JWT refresh, and OTP secrets.
- Render prompts for the SMS endpoint and API key.
- Render health checks use `/api/v1/healthz`.
- The build overlays the committed migration history, and the start command runs `prisma migrate deploy` before starting the API.

To start it, sign in to Render, create a new Blueprint from the GitHub repository `Featuredapps/darb-delivery-platform`, review the resources and any charges, and confirm creation. The Blueprint does not create a Render account or deploy anything until an account owner confirms it.

**Free-plan warning:** this Blueprint currently selects free resources for validation only. Render's free web service sleeps after inactivity; free Postgres expires after 30 days and has no backups; free Key Value is in-memory and loses data on restart. This is not a production configuration. See Render's current limits: https://render.com/docs/free

The migration enables PostGIS as part of schema creation. Readiness must still be checked after deployment; a liveness response alone is not proof that the API can serve real requests.

## Production requirements

- Select paid resources with persistent Redis-compatible storage and managed database backups; review current pricing before confirming.
- Set `NODE_ENV=production` and use strong, distinct JWT and OTP secrets.
- Configure a real SMS provider that supports delivery to Syrian numbers. The current HTTP adapter sends a generic JSON body `{ "to": "+963...", "message": "..." }`; adapt it to the provider's documented API. This is not a verified Syrian SMS integration.
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
