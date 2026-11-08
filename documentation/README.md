# TRAIN X — Engineering & Product Documentation Index

Welcome to the central documentation repository for **TRAIN X**, the premium personal fitness trainer-booking platform.

---

## Documentation Index

| Document | Purpose |
|---|---|
| [01. Product Architecture](./01_PRODUCT_ARCHITECTURE.md) | High-level system overview, 3 user roles, non-negotiable gender matching rule, centralized pricing table, and 24 planned functional modules. |
| [02. Tech Stack & Reasoning](./02_TECH_STACK_AND_REASONING.md) | Justifications for Flutter (Riverpod, GoRouter, Dio), NestJS modular monolith, PostgreSQL, Prisma ORM, and Next.js 14 App Router. |
| [03. Project Structure](./03_PROJECT_STRUCTURE.md) | Complete directory tree and layer breakdown across `mobile/`, `backend/`, `admin/`, and `documentation/`. |
| [04. Backend Architecture](./04_BACKEND_ARCHITECTURE.md) | NestJS layered flow, security guards, gender invariant enforcement, atomic slot booking, and Razorpay webhook validation. |
| [05. Database Architecture Plan](./05_DATABASE_ARCHITECTURE_PLAN.md) | Relational schema specification, ER diagram, enums, relational tables, foreign keys, indexes, and full Prisma schema. |
| [06. API Design Conventions](./06_API_DESIGN_CONVENTIONS.md) | REST API standards, URL versioning (`/api/v1`), response envelopes, and comprehensive endpoint catalog for all modules. |
| [07. Auth & Security Strategy](./07_AUTH_AND_SECURITY_STRATEGY.md) | Dual-token refresh rotation, public isolation of Admin credentials, client privacy rules, and mobile secret isolation. |
| [08. Development Roadmap](./08_DEVELOPMENT_ROADMAP.md) | 8-phase milestone breakdown from foundation to production readiness. |
| [09. Local Setup Instructions](./09_LOCAL_SETUP_INSTRUCTIONS.md) | Step-by-step local developer guide for PostgreSQL, NestJS, Next.js, and Flutter environments. |
