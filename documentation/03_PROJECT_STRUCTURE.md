# TRAIN X — Project Folder Structure Specification

## 1. Monorepo Organization

```text
Train-x/
├── mobile/                        # Flutter cross-platform mobile application
│   ├── android/                   # Native Android configuration & gradle builds
│   ├── ios/                       # Native iOS Xcode workspace & Podfile
│   ├── assets/                    # Bundled brand assets (fonts, icons)
│   │   └── fonts/                 # Syne, Poppins, etc.
│   ├── lib/                       # Flutter Dart source code
│   │   ├── core/                  # Shared primitives, network, theme, security
│   │   │   ├── config/            # Env variables, API endpoints
│   │   │   ├── network/           # Dio client, auth interceptor, error handler
│   │   │   ├── storage/           # FlutterSecureStorage wrapper
│   │   │   ├── theme/             # AppTheme, typography, palette tokens
│   │   │   └── router/            # GoRouter configuration & role redirect guards
│   │   ├── features/              # Feature-first domain modules
│   │   │   ├── auth/              # Login, register, token refresh, role selection
│   │   │   ├── onboarding/        # Client & Trainer onboarding questionnaires
│   │   │   ├── client_home/       # Client dashboard, workout summary
│   │   │   ├── trainer_home/      # Trainer dashboard, today's appointments
│   │   │   ├── discovery/         # Gender-matched trainer search & filters
│   │   │   ├── booking/           # 60-min slot calendar, confirmation
│   │   │   ├── plans/             # Subscription plan purchase, credit balance
│   │   │   └── profile/           # User details, emergency contacts, logout
│   │   └── main.dart              # App bootstrap & ProviderScope initialization
│   ├── test/                      # Unit, provider, and widget test suites
│   ├── pubspec.yaml               # Flutter package dependencies
│   └── analysis_options.yaml      # Strict Dart lint rules
│
├── backend/                       # NestJS API application
│   ├── src/
│   │   ├── core/                  # Cross-cutting framework concerns
│   │   │   ├── config/            # Env validation via Zod / Joi
│   │   │   ├── database/          # PrismaService & database extensions
│   │   │   ├── filters/           # Global HttpException & DomainException filter
│   │   │   ├── guards/            # JwtAuthGuard, RolesGuard, GenderGuard
│   │   │   ├── interceptors/      # TransformResponse, Logging, Timeout
│   │   │   └── decorators/        # @CurrentUser(), @Roles(), @Public()
│   │   ├── modules/               # Domain business modules
│   │   │   ├── auth/              # JWT, refresh rotation, login/register/logout
│   │   │   ├── users/             # Common user entity & profile services
│   │   │   ├── clients/           # Client profile, fitness goals
│   │   │   ├── trainers/          # Trainer verification, specialties, bio
│   │   │   ├── matching/          # Gender-matching & search engine
│   │   │   ├── cities/            # City & geo-zone configuration
│   │   │   ├── plans/             # Standardized pricing plans catalog
│   │   │   ├── credits/           # Ledger-backed session credit engine
│   │   │   ├── availability/      # Trainer 60-min slot schedule manager
│   │   │   ├── bookings/          # Atomic booking transactions & validation
│   │   │   ├── payments/          # Razorpay order generation & webhook HMAC
│   │   │   ├── notifications/     # FCM push notification dispatcher
│   │   │   ├── reviews/           # Post-session verified rating system
│   │   │   ├── safety/            # Incident reporting & SOS escalations
│   │   │   └── admin/             # Verification queue, audit logs, metrics
│   │   ├── app.module.ts          # Root NestJS application module
│   │   └── main.ts                # Bootstrap, Swagger, CORS, ValidationPipe
│   ├── prisma/
│   │   ├── schema.prisma          # PostgreSQL relational schema definition
│   │   ├── migrations/            # Version-controlled SQL migration scripts
│   │   └── seed.ts                # Initial city, pricing plans, and admin seed
│   ├── test/                      # E2E test suites (Supertest)
│   ├── tsconfig.json              # TypeScript compilation config
│   └── package.json               # NestJS dependencies & scripts
│
├── admin/                         # Next.js 14 Web Admin Portal
│   ├── src/
│   │   ├── app/                   # App Router pages (login, trainers, bookings, etc.)
│   │   ├── components/            # Reusable UI components (tables, badges, modals)
│   │   ├── lib/                   # API client, session management, formatters
│   │   └── types/                 # TypeScript interfaces shared from API schemas
│   ├── public/                    # Static admin assets
│   ├── tailwind.config.ts         # Tailwind CSS styling configuration
│   ├── tsconfig.json              # Next.js TypeScript config
│   └── package.json               # Next.js dependencies & scripts
│
├── documentation/                 # Technical & Product Architecture Specs
│   ├── 01_PRODUCT_ARCHITECTURE.md
│   ├── 02_TECH_STACK_AND_REASONING.md
│   ├── 03_PROJECT_STRUCTURE.md
│   ├── 04_BACKEND_ARCHITECTURE.md
│   ├── 05_DATABASE_ARCHITECTURE_PLAN.md
│   ├── 06_API_DESIGN_CONVENTIONS.md
│   ├── 07_AUTH_AND_SECURITY_STRATEGY.md
│   ├── 08_DEVELOPMENT_ROADMAP.md
│   ├── 09_LOCAL_SETUP_INSTRUCTIONS.md
│   └── README.md                  # Documentation Table of Contents
│
├── package.json                   # Root monorepo workspace orchestrator
└── .gitignore                     # Unified multi-stack gitignore
```
