# TRAIN X — Premium Fitness Trainer-Booking Platform

**TRAIN X** is an on-demand, premium personal fitness trainer booking platform built for high-touch personal training sessions.

---

## Monorepo Architecture

This repository is structured as a clean, modular monorepo:

- **`mobile/`**: Flutter cross-platform mobile application for Android & iOS (Riverpod, GoRouter, Dio, Flutter Secure Storage).
- **`backend/`**: Enterprise NestJS REST API with PostgreSQL, Prisma ORM, JWT dual-token auth, and Razorpay integration.
- **`admin/`**: Next.js 14 (App Router) web dashboard with Tailwind CSS for platform operators.
- **`documentation/`**: Comprehensive product, technical, and architectural documentation.

---

## Documentation Quick Links

- [Documentation Index](documentation/README.md)
- [01. Product Architecture](documentation/01_PRODUCT_ARCHITECTURE.md)
- [02. Tech Stack & Reasoning](documentation/02_TECH_STACK_AND_REASONING.md)
- [03. Project Structure](documentation/03_PROJECT_STRUCTURE.md)
- [04. Backend Architecture](documentation/04_BACKEND_ARCHITECTURE.md)
- [05. Database Architecture Plan](documentation/05_DATABASE_ARCHITECTURE_PLAN.md)
- [06. API Design Conventions](documentation/06_API_DESIGN_CONVENTIONS.md)
- [07. Auth & Security Strategy](documentation/07_AUTH_AND_SECURITY_STRATEGY.md)
- [08. Master Development Roadmap](documentation/08_DEVELOPMENT_ROADMAP.md)
- [09. Local Setup Instructions](documentation/09_LOCAL_SETUP_INSTRUCTIONS.md)

---

## Core Invariants

1. **Mandatory Gender-Matching**: Male clients can book male trainers only; female clients can book female trainers only. Enforced at backend business logic & database query level.
2. **Trainer Verification Gate**: Only admin-verified and active trainers are discoverable and bookable.
3. **Platform-Wide Standard Pricing**: All trainers follow centrally managed pricing plans (₹500 for 1 Day up to ₹52,999 for 6-Month Transformation).
4. **Backend is Source of Truth**: Pricing, slot availability, roles, and payment verification are strictly validated on the server.
