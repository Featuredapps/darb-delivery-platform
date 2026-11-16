# DARB Backend

NestJS API with Prisma, PostgreSQL/PostGIS and Redis.

## Readiness

- `GET /api/v1/health` checks both PostgreSQL and Redis and returns HTTP 503 if either dependency is unavailable.
- The endpoint is intended for the hosting platform's health-check configuration.

## Authentication and SMS

OTP requests are rate-limited and OTP values are stored as HMAC digests in Redis. In development, messages are written to the server log only. In production, the backend uses the SMS Syria REST API v1.

Configure these server-side environment variables:

- `SMS_API_URL=https://smssyria.net/api/v1/messages`
- `SMS_API_KEY`: private API key from the SMS Syria account
- `SMS_SENDER_ID`: sender ID approved/configured in that account

The SMS key must never be added to Flutter, the website, Git history, or chat. SMS sending is not active until a valid key, funded provider account, and accepted sender ID are configured and a real OTP is tested.

## Main API routes

| Method | Route | Access |
|---|---|---|
| POST | `/api/v1/auth/otp/request` | Public |
| POST | `/api/v1/auth/otp/verify` | Public |
| POST | `/api/v1/auth/refresh` | Public |
| GET | `/api/v1/auth/me` | Authenticated |
| GET | `/api/v1/cities` | Public |
| GET | `/api/v1/vendors?cityId=&locale=ar` | Public |
| GET | `/api/v1/vendors/:id` | Public |
| GET | `/api/v1/vendors/mine` | Vendor |
| GET | `/api/v1/vendors/:vendorId/products?locale=ar` | Public |
| POST | `/api/v1/vendors/apply` | Customer |
| POST | `/api/v1/drivers/apply` | Customer |
| GET/POST | `/api/v1/addresses` | Customer |
| POST | `/api/v1/vendor/products` | Approved vendor |
| POST | `/api/v1/orders` | Customer |
| GET | `/api/v1/orders/mine` | Customer |
| GET | `/api/v1/orders/vendor` | Vendor |
| GET | `/api/v1/orders/driver/available` | Driver |
| GET | `/api/v1/orders/driver/mine` | Driver |
| POST | `/api/v1/orders/:id/claim` | Driver |
| PATCH | `/api/v1/orders/:id/status` | Owning vendor/driver |
| GET | `/api/v1/drivers/me` | Driver |
| PATCH | `/api/v1/drivers/online` | Driver |
| GET | `/api/v1/admin/overview` | Admin |\n| GET | `/api/v1/admin/cities` | Admin |\n| PATCH | `/api/v1/admin/cities/:id/status` | Admin |\n| GET | `/api/v1/admin/delivery-zones` | Admin |\n| POST | `/api/v1/admin/delivery-zones` | Admin |\n| PATCH | `/api/v1/admin/delivery-zones/:id` | Admin |\n| GET | `/api/v1/admin/vendors/pending` | Admin |
| PATCH | `/api/v1/admin/vendors/:id/status` | Admin |
| GET | `/api/v1/admin/drivers/pending` | Admin |
| PATCH | `/api/v1/admin/drivers/:id/status` | Admin |

## Remaining production integrations

- Firebase Cloud Messaging credentials and device-token registration.
- Maps provider, geocoding, driver location updates and customer live tracking.
- Admin web/mobile console and controlled first-admin bootstrap.
- Real database migration application and end-to-end order tests.
- Signed Android release build and physical-device testing.

Do not treat integrations as active until their credentials are configured and end-to-end tests pass.
