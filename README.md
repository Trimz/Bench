# Bench

Bench is a macOS-first project tracker with a Vercel-hosted backend.

## Structure

- `apps/api`: Next.js backend for Vercel, Prisma, auth, and project APIs
- `apps/macos`: SwiftUI macOS app shell that can be opened directly in Xcode

## Quick Start

### API

1. Copy `apps/api/.env.example` to `apps/api/.env`
2. Set `DATABASE_URL` and `SESSION_SECRET`
3. Run `npm install` inside `apps/api` if dependencies are not already present
4. Run `npm run prisma:generate --workspace api`
5. Run `npm run dev:api`

### macOS App

1. Open `apps/macos/Package.swift` in Xcode
2. Run the `BenchMac` executable target as a macOS app

## Current Status

Milestone 1 is underway:

- monorepo skeleton created
- Vercel-ready API scaffold created
- Prisma schema added
- starter auth and project endpoints added
- SwiftUI macOS shell added
