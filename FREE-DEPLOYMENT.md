# DARB: zero-cost preview infrastructure

This configuration is for development, demos, and early integration tests only. It is
not a production hosting guarantee.

## Free-tier components

- **API:** Render Free Web Service in Frankfurt. It sleeps after 15 minutes without
  inbound traffic; the first request after sleep can take about a minute.
- **Database:** Supabase Free PostgreSQL (500 MB). Enable the PostGIS extension before
  deploying. Free projects can pause after one week of inactivity and do not include
  automatic backups.
- **Redis:** Upstash Redis Free (256 MB, 500,000 commands/month, 10 GB monthly
  bandwidth). Keep cache/ephemeral state here, not business records.

The Render Blueprint intentionally creates only the API. It does not create a Render
Postgres database that expires after 30 days or a Render Key Value instance whose
contents are lost on restart.

## One-time setup

1. Create a Supabase project on the Free plan and choose a region close to Frankfurt.
2. In Supabase, enable the PostGIS extension. The current Prisma migration issues
   `CREATE EXTENSION IF NOT EXISTS postgis` and uses unqualified `geography` types;
   verify the extension schema/search path is compatible before running migrations.
   Do not run `prisma db push` against the project.
3. Copy the PostgreSQL connection string from Supabase. Use the session pooler if the
   Render service cannot connect directly. Keep the password private.
4. Create one Redis database on the Upstash Free plan and copy its TLS connection URL
   (`rediss://...`) into `REDIS_URL`.
5. In Render, create a Blueprint from this repository and select the Free plan for
   `darb-api`. Set the prompted environment variables:
   - `DATABASE_URL`: Supabase PostgreSQL connection string
   - `REDIS_URL`: Upstash TLS Redis connection URL
   - Keep the generated `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, and `OTP_SECRET` values.
   - For the MsgPlus adapter, set `SMS_PROVIDER=msgplus`, `MSGPLUS_API_KEY`,
     `MSGPLUS_SENDER_ID`, and `MSGPLUS_TEMPLATE_ID=3`. The sender ID and template
     must be approved by MsgPlus. The adapter sends `P1=مستخدمنا`, `P2=درب`, and
     `P3=<six-digit OTP>` to the account's template using `POST /api/send`.
     OTP delivery remains unverified until an explicitly approved live test is performed.
     Do not send test SMS or consume prepaid balance without approval.
6. Render generates the JWT and OTP secrets automatically. Wait for deployment, then
   verify `/api/v1/healthz` and `/api/v1/readyz`.

## Hard limitations

- This is a **$0 preview**, not a reliable commercial delivery platform.
- Render Free uses 512 MB RAM / very low CPU and sleeps when idle.
- Supabase Free is limited to 500 MB and can pause after inactivity; it has no automatic
  backups on the Free tier.
- Upstash Free is limited to 500K commands/month and 256 MB.
- SMS to Syrian numbers, Firebase push notifications, and production map/geocoding
  credentials are not included in these hosting tiers and are not configured here.
- Do not store real customer data or rely on this setup for live orders, payments, or
  driver dispatch. Move to durable paid infrastructure and verify backups before launch.

Official limits:
- https://render.com/docs/free
- https://supabase.com/pricing
- https://supabase.com/docs/guides/database/extensions/postgis
- https://upstash.com/pricing/redis
