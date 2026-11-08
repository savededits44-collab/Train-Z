# TRAIN X — Local Development Setup Instructions

## 1. Prerequisites
- **Operating System**: macOS (Apple Silicon ARM64 recommended)
- **Node.js**: `v24.21.0` (or `v20+` LTS)
- **Package Manager**: `npm v11+`
- **Flutter SDK**: `3.47.9+` (stable channel)
- **Dart SDK**: `3.13.7+`
- **Database**: PostgreSQL 16 (Postgres.app or Homebrew service)
- **JDK**: Java 17+ (available via Android Studio at `/Applications/Android Studio.app/Contents/jbr/Contents/Home`)

---

## 2. PostgreSQL Database Setup

1. Verify PostgreSQL is active:
   ```bash
   pg_isready
   ```
2. Verify development database exists (or create it):
   ```bash
   createdb trainx_dev
   ```

---

## 3. Backend Setup (`backend/`)

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Configure environment variables in `backend/.env`:
   ```env
   NODE_ENV=development
   PORT=4000
   DATABASE_URL="postgresql://imranmulla@localhost:5432/trainx_dev?schema=public"
   JWT_SECRET="trainx-super-secure-dev-jwt-secret-key"
   JWT_REFRESH_SECRET="trainx-super-secure-dev-refresh-secret-key"
   JWT_EXPIRES_IN="15m"
   JWT_REFRESH_EXPIRES_IN="7d"
   RAZORPAY_KEY_ID="rzp_test_placeholder"
   RAZORPAY_KEY_SECRET="rzp_secret_placeholder"
   RAZORPAY_WEBHOOK_SECRET="whsec_placeholder"
   ```
4. Generate Prisma Client and run migrations:
   ```bash
   npx prisma migrate dev --name init
   npx prisma db seed
   ```
5. Start development server:
   ```bash
   npm run start:dev
   ```
   Swagger docs will be available at: `http://localhost:4000/api/docs`

---

## 4. Admin Dashboard Setup (`admin/`)

1. Navigate to admin directory:
   ```bash
   cd admin
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Configure environment variables in `admin/.env.local`:
   ```env
   NEXT_PUBLIC_API_URL="http://localhost:4000/api/v1"
   ```
4. Start Next.js development server:
   ```bash
   npm run dev
   ```
   Admin web portal will be accessible at: `http://localhost:3000`

---

## 5. Mobile Application Setup (`mobile/`)

1. Navigate to mobile directory:
   ```bash
   cd mobile
   ```
2. Get Flutter packages:
   ```bash
   flutter pub get
   ```
3. Run static analyzer:
   ```bash
   flutter analyze
   ```
4. Launch on connected Android Emulator or iOS Simulator:
   ```bash
   flutter run
   ```
