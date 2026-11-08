# TRAIN X — Authentication & Security Strategy Specification

## 1. Authentication Architecture

### 1.1 Dual-Token Refresh Rotation
- **Access Token**: Short-lived (15 minutes). Formatted as standard signed JWT (RS256 or HS256). Contains `sub` (userId), `role` (CLIENT, TRAINER, ADMIN), and `gender` (MALE, FEMALE).
- **Refresh Token**: Long-lived (7 days). Stored as an SHA-256 hash in the `session_tokens` table.
- **Rotation Mechanics**:
  - Every call to `/api/v1/auth/refresh` invalidates the old refresh token and issues a new pair.
  - If a revoked token is presented, the backend marks the entire user session as compromised and revokes all active tokens for that user.

### 1.2 Administrative Authentication Isolation
- Admin registration is strictly blocked from all public endpoints.
- Admin credentials are seeded via secure server-side commands or created directly by existing Super Admins.
- Admin authentication requests require role confirmation before processing password checks to thwart timing attacks.

---

## 2. Invariant Security Rules

### 2.1 Backend Gender Invariant Enforcement
```typescript
// Architectural Rule: Never trust client parameters for matching rules
export class GenderGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const user = request.user; // from verified JWT
    const targetTrainerGender = request.body.trainerGender || request.query.gender;

    if (user.role === Role.CLIENT && targetTrainerGender) {
      if (user.gender !== targetTrainerGender) {
        throw new ForbiddenException({
          code: 'GENDER_MISMATCH_DISALLOWED',
          message: 'Clients may only book trainers of the same gender.',
        });
      }
    }
    return true;
  }
}
```

### 2.2 Payment Integrity Guarantee
- Razorpay order amounts are computed on the server based on the database price of the requested plan. The client cannot modify or tamper with amounts.
- Webhook signature verification uses `crypto.createHmac('sha256', secret)` compared via `crypto.timingSafeEqual`.

### 2.3 Client Personal Data & Privacy Protection
- Trainer profiles never expose client home addresses or private phone numbers until a session booking is confirmed and in status `CONFIRMED`.
- Even upon booking, trainer sees only the specified session location and first name + initial.
- All sensitive KYC documents (identity cards, certifications) uploaded by trainers are stored in private S3 buckets with time-limited pre-signed URLs accessible only to Admin roles.

### 2.4 Mobile Client Secret Isolation
- Zero API secrets, payment secret keys, or webhook secrets are placed in the Flutter application.
- The mobile app only receives public identifiers: `razorpay_key_id` and the server-generated `order_id`.
- Refresh tokens are saved in hardware-backed storage via `flutter_secure_storage` (iOS Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and Android `EncryptedSharedPreferences`).
