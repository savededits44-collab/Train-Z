# TRAIN X — API Design Conventions & OpenAPI Specification

## 1. Core Principles
- **Protocol**: HTTPS only.
- **Base URI & Versioning**: `/api/v1` prefix on all domain routes.
- **Data Exchange Format**: JSON (`application/json; charset=utf-8`).
- **OpenAPI Documentation**: Automatically generated using `@nestjs/swagger` at `/api/docs`.
- **Case Conventions**:
  - URL segments: `kebab-case` (e.g. `/api/v1/session-credits`)
  - JSON keys: `camelCase` (e.g. `isApproved`, `sessionCount`)

---

## 2. Standardized Response Envelope

### 2.1 Success Envelope (2xx)
```json
{
  "success": true,
  "data": { ... },
  "message": "Optional human-readable feedback",
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 45
  }
}
```

### 2.2 Error Envelope (4xx / 5xx)
```json
{
  "success": false,
  "error": {
    "code": "GENDER_MISMATCH_DISALLOWED",
    "message": "Clients can only book trainers of the same gender.",
    "statusCode": 403,
    "timestamp": "2026-11-08T13:20:00.000Z",
    "path": "/api/v1/bookings",
    "details": []
  }
}
```

---

## 3. Key Endpoint Catalog

### 3.1 Authentication & Profile (`/api/v1/auth`)
| Method | Endpoint | Access | Description |
|---|---|---|---|
| `POST` | `/api/v1/auth/register` | Public | Register as `CLIENT` or `TRAINER` (requires verified gender). |
| `POST` | `/api/v1/auth/login` | Public | Authenticate email/phone + password; returns access & refresh tokens. |
| `POST` | `/api/v1/auth/refresh` | Public | Refresh token rotation endpoint. |
| `POST` | `/api/v1/auth/logout` | Authenticated | Revokes current session token. |
| `GET`  | `/api/v1/auth/me` | Authenticated | Fetches authenticated user profile, role, and active status. |

### 3.2 Trainer Discovery (`/api/v1/trainers`)
| Method | Endpoint | Access | Description |
|---|---|---|---|
| `GET` | `/api/v1/trainers` | Client Only | List active, approved trainers. **Automatically filtered to matching gender.** |
| `GET` | `/api/v1/trainers/:id` | Client Only | Inspect trainer profile. Rejects with 403 if gender does not match client. |
| `GET` | `/api/v1/trainers/:id/slots` | Client Only | Returns open 60-minute slots for the selected date. |

### 3.3 Platform Plans & Credits (`/api/v1/plans`)
| Method | Endpoint | Access | Description |
|---|---|---|---|
| `GET`  | `/api/v1/plans` | Public | Returns the 6 platform-wide standardized pricing plans. |
| `GET`  | `/api/v1/credits/balance` | Client Only | Returns active credit count and expiration schedule. |

### 3.4 Payments (`/api/v1/payments`)
| Method | Endpoint | Access | Description |
|---|---|---|---|
| `POST` | `/api/v1/payments/create-order` | Client Only | Initiates Razorpay Order for a specific `planId`. |
| `POST` | `/api/v1/payments/verify` | Client Only | Validates Razorpay signature and deposits session credits. |
| `POST` | `/api/v1/payments/webhook` | External (Razorpay) | Ingests asynchronous payment events with HMAC signature verification. |

### 3.5 Bookings (`/api/v1/bookings`)
| Method | Endpoint | Access | Description |
|---|---|---|---|
| `POST` | `/api/v1/bookings` | Client Only | Atomically books a 60-min slot using an active credit. Enforces gender match. |
| `GET`  | `/api/v1/bookings/my` | Client / Trainer | Returns user's upcoming and past session appointments. |
| `POST` | `/api/v1/bookings/:id/verify-otp`| Trainer Only | Validates 6-digit client OTP at session start. |
| `POST` | `/api/v1/bookings/:id/cancel` | Client / Trainer | Handles cancellation with credit restoration rules. |

### 3.6 Administration (`/api/v1/admin`)
| Method | Endpoint | Access | Description |
|---|---|---|---|
| `GET`  | `/api/v1/admin/trainers/pending` | Admin Only | Queue of trainers awaiting certificate and ID verification. |
| `PATCH`| `/api/v1/admin/trainers/:id/approve`| Admin Only | Approves a trainer profile and logs audit entry. |
| `GET`  | `/api/v1/admin/audit-logs` | Admin Only | Immutable log of administrative decisions and adjustments. |
| `PATCH`| `/api/v1/admin/cities/:id` | Admin Only | Toggle active status for service cities and postal zones. |
