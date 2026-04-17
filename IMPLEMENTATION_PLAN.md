# Bench Implementation Plan

## 1. Product Goal

Bench is a macOS app for tracking the state of personal or professional projects through lightweight written updates.

The app should let a user:

- sign in
- create a project
- post updates to that project
- see a ranked main list of projects that need attention
- read an LLM-generated summary of project progress

The architecture should support a future iOS client without requiring backend redesign.

## 2. Product Scope for V1

V1 should include:

- user registration and login
- a main screen showing all projects in a ranked stack/list
- project creation with a simple name field
- a project detail screen
- update history for each project
- an input area for adding a new update
- an automatically generated summary for each project
- a visual recency indicator for each project

V1 should not include:

- team collaboration
- file attachments
- push notifications
- offline sync
- social login
- iOS-specific UI

## 3. Recommended Architecture

### Client

- Native macOS app built with `SwiftUI`
- Networking layer using `URLSession`
- Secure token storage in macOS Keychain

### Backend

- `Next.js` project deployed on `Vercel`
- API implemented with Route Handlers or `/api` endpoints
- `Node.js` runtime for API routes
- Background-friendly architecture for later queue support

### Database

- `PostgreSQL`
- Hosted through `Neon` or `Supabase`
- Connected to Vercel using environment variables or Marketplace integration

### ORM

- `Prisma` preferred for speed of setup and schema clarity

### LLM Integration

- `Gemini API` called from the backend only
- Generated summaries stored in the database
- API key stored in Vercel environment variables

## 4. Why This Architecture

This split keeps secrets and ranking logic on the server, keeps the macOS app lightweight, and makes it straightforward to add an iOS app later using the same API.

Using Vercel is appropriate for Bench because the backend workload is mostly CRUD operations plus periodic LLM summarization. That fits well with serverless functions and avoids running a traditional long-lived server.

## 5. Core User Flows

### Flow A: Sign Up / Login

1. User opens Bench
2. User signs up or logs in with email and password
3. App stores session token securely
4. App loads ranked projects

### Flow B: Create Project

1. User clicks `+`
2. User enters project name
3. Project is created
4. Project appears in the ranked project list

### Flow C: Open Project

1. User selects a project from the main stack/list
2. App opens project detail view
3. Detail view shows:
   - summary on the left
   - update timeline/history in the main content area
   - update composer on the right

### Flow D: Post Update

1. User writes a short update
2. User presses send
3. Backend stores the update
4. Project `last_update_at` is refreshed
5. Summary regeneration is triggered
6. Ranked list and recency indicator update

## 6. Functional Requirements

### Authentication

- Email/password registration
- Email/password login
- Password hashing with `argon2` or `bcrypt`
- Authenticated API access via session token or JWT
- Logout support

### Project Management

- Create project
- List projects for current user
- View project details
- Rename project in a later minor release if needed

### Updates

- Add text-only project updates
- Show updates in reverse chronological order
- Persist timestamps for all updates

### Summaries

- Generate a summary of the project’s state using Gemini
- Store the latest summary in the database
- Refresh summary after new updates
- Allow manual regenerate endpoint for fallback/admin/debugging

### Ranking and Attention

- Main screen should prioritize:
  - recently active projects
  - projects with meaningful recent change
  - stale projects that need attention after a period of inactivity

### Recency Indicator

- Green: updated recently
- Yellow: somewhat stale
- Red: stale and needs attention

## 7. Non-Functional Requirements

- API must be reusable by a future iOS app
- All secrets must remain server-side
- Auth flow must be production-safe
- Database schema must support growth without redesign
- Summary generation failures must not block update creation
- App should feel fast on normal project volumes

## 8. Data Model

### `users`

- `id`
- `email`
- `password_hash`
- `created_at`
- `updated_at`

### `sessions`

- `id`
- `user_id`
- `token_hash` or opaque session token reference
- `expires_at`
- `created_at`

### `projects`

- `id`
- `user_id`
- `name`
- `created_at`
- `updated_at`
- `last_update_at`
- `activity_score`

### `project_updates`

- `id`
- `project_id`
- `content`
- `created_at`

### `project_summaries`

- `id`
- `project_id`
- `summary_text`
- `source_update_count`
- `updated_at`

Optional later tables:

- `summary_jobs`
- `audit_logs`
- `device_sessions`

## 9. Ranking Strategy

The ranking should not be pure recency. If it is, old but important projects disappear. Bench should instead rank by an attention score.

Suggested score inputs:

- recent update activity
- total number of updates in the recent window
- time since last update
- resurfacing boost after inactivity threshold

### Proposed V1 Formula

For each project:

- base activity boost if updated in last 72 hours
- moderate score for update count in the last 14 days
- decay after 3 days of inactivity
- resurfacing boost after 14 days without update

Example behavior:

- actively worked-on projects stay near the top
- dormant projects gradually sink
- very stale projects rise again so the user notices them

This logic should live on the backend, not in the macOS app.

## 10. Recency Indicator Rules

Use backend-computed status values:

- `green` if last update was within 3 days
- `yellow` if last update was 4 to 10 days ago
- `red` if last update was more than 10 days ago

If a project has no updates yet:

- show `red`
- optionally label it as needing first update

## 11. Summary Generation Strategy

### V1

- After each new update, trigger summary regeneration
- If generation succeeds, replace stored project summary
- If generation fails, keep the previous summary and return success for the update itself

### Prompt Shape

The backend should send Gemini:

- project name
- existing summary if available
- recent updates or full update history if still small
- instruction to produce a concise factual project summary

Summary output should be:

- concise
- neutral
- cumulative
- useful for quickly understanding current status

### Later Optimization

- generate incremental summaries
- queue generation asynchronously
- store generation status and retry metadata

## 12. API Design

### Auth

- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/logout`
- `GET /api/auth/me`

### Projects

- `GET /api/projects`
- `POST /api/projects`
- `GET /api/projects/:id`
- `PATCH /api/projects/:id`

### Updates

- `GET /api/projects/:id/updates`
- `POST /api/projects/:id/updates`

### Summaries

- `GET /api/projects/:id/summary`
- `POST /api/projects/:id/summary/regenerate`

### Response Design

Project list responses should include:

- `id`
- `name`
- `lastUpdateAt`
- `activityScore`
- `recencyStatus`
- `updateCount`
- `summaryPreview` optional later

## 13. Backend Implementation Plan

### Phase 1: Project Setup

- Create `Next.js` backend project
- Add `TypeScript`, `Prisma`, linting, formatting
- Configure environment variables
- Connect PostgreSQL
- Create initial schema and migrations

### Phase 2: Authentication

- Implement registration and login routes
- Add password hashing
- Implement session handling
- Add auth middleware/helpers

### Phase 3: Projects and Updates

- Create project CRUD endpoints needed for V1
- Create update creation and listing endpoints
- Update `last_update_at` on new update

### Phase 4: Ranking and Summary Logic

- Implement ranking score calculation
- Add summary generation service
- Trigger summary regeneration after update creation

### Phase 5: Hardening

- Validation with `zod`
- basic rate limiting if needed
- structured error responses
- logging and observability

## 14. macOS App Implementation Plan

### Phase 1: App Skeleton

- Create `SwiftUI` macOS app
- Add app navigation structure
- Add API client abstraction
- Add secure token storage

### Phase 2: Authentication UI

- Login screen
- Registration screen
- Session restoration on app launch

### Phase 3: Main Project Screen

- Ranked list or card stack of projects
- `+` button for project creation
- Recency indicator dot per project

For V1, implement the stack as a polished ranked card list first. A more experimental visual stack can be added after the logic is stable.

### Phase 4: Project Detail Screen

- Left panel: summary
- Center: updates history
- Right panel: update composer

### Phase 5: State Handling and Error UX

- loading states
- empty states
- retry states
- summary refresh feedback

## 15. Suggested UI Structure

### Main Screen

Each project card should show:

- project name
- recency dot
- last update timestamp
- optional latest summary snippet

Sort order should come from backend ranking rather than client-side sorting.

### Project Detail Screen Layout

- left column: generated summary card
- main column: update history feed
- right column: text area and send button

This maps well to macOS window layout and gives the summary a persistent role without interrupting writing flow.

## 16. Security Plan

- Hash passwords using a modern algorithm
- Never store Gemini key in the client
- Use HTTPS-only API communication
- Use secure, expiring session tokens
- Validate all request payloads on the server
- Check resource ownership on every project/update route

## 17. Vercel Deployment Plan

### Hosting Model

- Deploy backend as a Vercel project
- Use server functions for API endpoints
- Store secrets in Vercel environment variables

### Required Environment Variables

- `DATABASE_URL`
- `GEMINI_API_KEY`
- `SESSION_SECRET`
- `APP_BASE_URL`

Possible later additions:

- `CRON_SECRET`
- logging provider keys

### Deployment Steps

1. Create Vercel project from repo
2. Provision PostgreSQL through Neon or Supabase
3. Add environment variables in Vercel
4. Run Prisma migrations
5. Deploy preview
6. Test auth, project creation, update creation, summary generation
7. Promote to production

## 18. Operations and Observability

At minimum:

- log auth failures
- log update creation failures
- log summary generation failures
- log slow API responses

Later:

- add Vercel Observability
- add structured logging sink
- add alerting for repeated summary failures

## 19. Future iOS Readiness

To keep iOS easy later:

- keep API resource design clean and stable
- keep ranking logic server-side
- keep response models platform-neutral
- consider extracting shared Swift models/networking later

## 20. Recommended Milestones

### Milestone 1

Backend foundation:

- Next.js API project
- database schema
- authentication

### Milestone 2

Core project tracking:

- create/list/open projects
- create/list updates
- ranking logic

### Milestone 3

macOS usable product:

- auth UI
- project list
- project detail
- update posting

### Milestone 4

LLM enhancement:

- Gemini integration
- summary persistence
- summary refresh behavior

### Milestone 5

Release hardening:

- error handling
- logs
- deployment polish
- production verification

## 21. Immediate Next Step

The next practical step is to scaffold two workspaces:

- `apps/macos` for the SwiftUI app
- `apps/api` for the Vercel-hosted Next.js backend

Then implement Milestone 1 first so the data model and auth contract are fixed before UI work accelerates.
