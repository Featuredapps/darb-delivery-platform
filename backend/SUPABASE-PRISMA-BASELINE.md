# Supabase / Prisma migration baseline

The DARB Supabase project already had the first three application migrations applied through Supabase before the backend was connected to Prisma's migration runner. Supabase tracks those operations in `supabase_migrations.schema_migrations`; Prisma independently tracks them in `public."_prisma_migrations"`.

To prevent `prisma migrate deploy` from attempting to recreate existing tables, the Prisma history table was initialized on 2026-11-16 after checking the live schema.

## Verified live state

- 19 application tables exist.
- Row Level Security is enabled on all 19 application tables.
- All 11 foreign-key indexes from the third migration exist.
- PostGIS is installed.
- The Prisma history table contains the three completed migrations below.

## Baselined migrations

| Prisma migration | Purpose |
| --- | --- |
| `20261116162000_initial` | Initial enums, tables, constraints, foreign keys and spatial indexes |
| `20261116180000_enable_rls_app_tables` | Enable RLS on the 19 application tables |
| `20261116182000_index_foreign_keys` | Add indexes for foreign-key columns |

The `checksum` values in `public."_prisma_migrations"` were calculated from the exact UTF-8 migration files committed in this repository. All three records have `finished_at` set, `rolled_back_at` null and `applied_steps_count = 1`.

The Prisma history table itself has RLS enabled. Do not delete or edit these records, and do not run `prisma migrate resolve --applied` for these same migrations again.

## Deployment requirements still outstanding

This baseline does **not** mean the API is deployed. A deployment still requires:

1. A Supabase PostgreSQL connection URL using the database password (prefer the Supabase pooler in the deployment region if appropriate). Never use the Supabase anon/publishable key as a database password.
2. The Redis connection URL from the existing Upstash database, stored only as a protected environment variable.
3. A configured SMS provider and valid credentials before real OTP login can work.
4. Render service environment variables and a successful production build/start/health check.

Keep all database passwords, Redis passwords, SMS credentials and JWT secrets out of Git, APKs, logs and client-side configuration.
