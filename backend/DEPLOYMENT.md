# Backend deployment and local secure setup

## Repository layout

The backend source is currently packaged inside the repository's `DARB-source.zip` archive under `darb-project/backend/`. The Android app is under `darb-project/mobile/`. The Render Blueprint at the repository root unpacks this archive during the build.

## Prepare secrets

Copy `.env.example` to `.env` for local development and replace every placeholder. Generate separate values for PostgreSQL, Redis, JWT access, JWT refresh, and OTP secrets. Never commit a real `.env`. Keep the initial administrator phone operator-controlled.

## Local stack

Extract `DARB-source.zip`, then run Docker Compose from the extracted `darb-project/backend/` directory. The Compose file starts PostgreSQL/PostGIS, Redis, and the API on local ports. It does not currently run a database migration automatically.

**Migration limitation:** there is no committed Prisma migration history. Do not use `prisma db push` as a production migration strategy. Before accepting real orders, generate, review, commit, and test an initial Prisma migration, then run `prisma migrate deploy` as a controlled release step.

## Render test deployment

The root `render.yaml` defines a test deployment in Frankfurt:
- Node API service, PostgreSQL 16, and Redis-compatible Key Value.
- Randomly generated JWT access, JWT refresh, and OTP secrets.
- Render prompts for the SMS endpoint and API key.

To start it, sign in to Render, create a new Blueprint from the GitHub repository `Featuredapps/darb-delivery-platform`, review the resources and any charges, and confirm creation. The Blueprint does not create a Render account or deploy anything until an account owner confirms it.

**Free-plan warning:** this Blueprint currently selects free resources for validation only. Render's free web service sleeps after inactivity; free Postgres expires after 30 days and has no backups; free Key Value is in-memory and loses data on restart. This is not a production configuration. See Render's current limits: https://render.com/docs/free

After the database is created, enable PostGIS with `CREATE EXTENSION postgis;` before initializing the schema. Render supports PostGIS, but the extension must be enabled in the database. The project has no committed production migration yet, so the schema must not be initialized automatically by a deployment command.

## Production requirements

- Select paid resources with persistent Redis-compatible storage and managed database backups; review current pricing before confirming.
- Set `NODE_ENV=production` and use strong, distinct JWT and OTP secrets.
- Configure a real SMS provider that supports delivery to Syrian numbers. The current HTTP adapter sends a generic JSON body `{ "to": "+963...", "message": "..." }`; adapt it to the provider's documented API. This is not a verified Syrian SMS integration.
- Keep the SMS API URL and key in the hosting provider's secret manager. Console SMS is not suitable for production.
- Enable PostGIS, commit reviewed Prisma migrations, and run `prisma migrate deploy` as a release step.
- Terminate HTTPS at the hosting provider's trusted edge. Do not expose PostgreSQL or Redis publicly.
- Add and verify health/readiness endpoints before configuring platform health checks. The current API source does not implement the `/api/v1/healthz` or `/api/v1/readyz` routes previously mentioned in older notes.
- Back up PostgreSQL and test restoration before accepting real orders. Test role authorization, order lifecycle, OTP rate limits, refresh-token rotation/revocation, and driver tracking.

## Android build

```sh
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_API_HOST/api/v1
```

The API URL must be a real HTTPS endpoint reachable from the device. An emulator address is not a production URL.

## Remaining external integrations

Firebase Cloud Messaging, live maps/geocoding, and a production Syrian SMS provider still require real provider accounts and credentials. A successful CI build does not prove these integrations work.
