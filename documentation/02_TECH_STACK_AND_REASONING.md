# TRAIN X — Technology Stack & Architectural Reasoning

## 1. Stack Overview

| Layer | Technology | Version / Tool | Core Rationale |
|---|---|---|---|
| **Mobile Client** | **Flutter** + **Dart** | Flutter 3.47+ / Dart 3.13+ | Single high-performance codebase targeting Android and iOS with native GPU-rendered 60/120fps UI. |
| **Mobile State** | **Flutter Riverpod** | `flutter_riverpod: ^2.5+` | Compile-safe, testable state management without BuildContext dependency leaks; ideal for reactive session tracking. |
| **Mobile Navigation** | **GoRouter** | `go_router: ^14.0+` | Declarative routing supporting deep-linking, authenticated redirect guards, and nested shell routes for role tabs. |
| **Mobile Networking** | **Dio** | `dio: ^5.4+` | Full interceptor pipeline for JWT injection, automatic token refresh rotation, and uniform error serialization. |
| **Mobile Security** | **Flutter Secure Storage** | `flutter_secure_storage: ^9.0+` | Hardware-backed Keychain (iOS) and KeyStore/EncryptedSharedPreferences (Android) for refresh tokens. |
| **Mobile Push** | **Firebase Messaging** | `firebase_messaging` | Industry-standard APNs/FCM delivery for time-critical booking alerts. |
| **Backend Framework** | **NestJS** | `NestJS 10+ / TypeScript 5+` | Modular architecture with enterprise Dependency Injection, built-in validation pipes, guards, and Swagger generation. |
| **Language / Runtime** | **Node.js** + **TypeScript** | Node 24 LTS / TS 5+ | Fast I/O async event loop with end-to-end type safety shared between backend and web admin contracts. |
| **Database & ORM** | **PostgreSQL 16** + **Prisma** | PostgreSQL 16 / Prisma 5+ | ACID-compliant relational integrity for financial credits and concurrent slot bookings with typesafe query generation. |
| **Admin Dashboard** | **Next.js** | `Next.js 14+ (App Router)` | Server-Side Rendering (SSR), React Server Components (RSC), and fast secure admin web portal. |
| **Admin Styling** | **Tailwind CSS** | `Tailwind v3+` | Rapid, consistent UI development conforming to Train X dark/lime aesthetic. |
| **Payments Gateway** | **Razorpay** | REST API + Webhooks | India-native UPI, cards, and netbanking support with HMAC webhook signature verification. |

---

## 2. Deep Dive: Architectural Reasoning

### 2.1 Backend: NestJS Modular Monolith vs Microservices
- **Decision**: Start with a well-structured **NestJS Modular Monolith**.
- **Reasoning**:
  - The business domain requires high transaction consistency between User gender, Subscription Credits, and Trainer Booking slots. Distributed transactions (2PC or Saga) across premature microservices introduce latency and failure modes.
  - NestJS modular boundaries (using isolated Modules, Services, and Repositories) ensure that if any module (e.g., Booking or Messaging) later requires horizontal scale, it can be extracted cleanly into an independent microservice with minimal refactoring.

### 2.2 Database: PostgreSQL + Prisma ORM
- **Decision**: Relational schema enforced by PostgreSQL constraints, accessed via Prisma.
- **Reasoning**:
  - **ACID Transactions**: Purchasing a credit pack and booking a slot must be atomic. A slot cannot be booked without debiting an available credit.
  - **Gender Integrity**: Relational check constraints and Prisma middleware can guarantee that cross-gender bookings are rejected at the database level.
  - **Declarative Migrations**: Prisma provides schema-driven migrations, full TypeScript type generation, and Prisma Studio for development administration.

### 2.3 Mobile: Riverpod + GoRouter Architecture
- **Decision**: Clean Feature-First Architecture (`lib/features/...`) with Riverpod Providers.
- **Reasoning**:
  - Eliminates Flutter `setState` prop drilling.
  - Riverpod allows mocking API clients effortlessly in widget and integration tests.
  - `GoRouter`'s `redirect` property listens directly to an `authProvider`, instantly switching routes between Splash, Auth, Client Shell, and Trainer Shell based on verified backend session claims.
