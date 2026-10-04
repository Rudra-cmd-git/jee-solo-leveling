# Claude Code Project Handoff

Read this file at the start of each session, then verify important status against the repository before making changes. Keep the **Current Status** section up to date when meaningful work is completed. Never put passwords, API keys, tokens, or other secrets in this file or commit them.

## Project

JEE Solo Leveling is planned as a gamified JEE study tracker with tasks, proof submissions, XP, ranks, and a leaderboard.

Planned stack:
- Next.js and React for the application
- Supabase for database and authentication
- Claude API for image/proof verification
- Vercel for hosting

## Current Status

Updated: 2026-10-04

### Priority 0: User Profile Creation & Column Security Foundation ✅ COMPLETE
- **Status**: FIXED AND DEPLOYED
- **Change**: Removed redundant frontend profile creation code from `web/src/lib/auth.ts`
  - Profiles are now created exclusively by database trigger (atomic, idempotent, secure)
  - Column security enforced on `public.users` (only `name` column is user-updatable)
  - RLS & Column security enforced on `public.tasks` (only `title` and `subject` are user-updatable; `id`, `user_id`, `xp_value`, `status`, `created_at`, `updated_at` are server-controlled)
  - Executable test suites in `backend/tests/`
  - No breaking changes to frontend
- **For Frontend Developers**: See section below
- **Backend Details**: See `backend/README.md` for deployment instructions

### Core Infrastructure
- The Supabase project is set up and migrations applied.
- The runnable Next.js app is in `web/`; npm commands should be run from that directory.
- Local environment variables are kept in `web/.env.local`; never publish their values.
- `npm run build` succeeds from `web/` with no errors (TypeScript clean).

### Features Implemented
- **Authentication**: Sign-in, sign-up, session management via Supabase.
  - Sign-up now passes name in auth metadata (extracted by database trigger)
  - Profiles auto-created by database trigger (atomic with auth.users INSERT)
- **Task Management**: Users can create tasks with title, subject, and XP value.
- **Submission Flow**: Users can submit proof (image URL) for verification via VisionSter API.
- **Verification**: Server-side route `/api/verify-submission` handles proof validation.
- **XP Awarding**: `public.award_xp()` function secured with `service_role` permission only.
  - Currently called from frontend (not ideal)
  - Next step: Move to server-side route ([[backend-xp-awarding]])
- **Dashboard**: Homepage (`/`) displays study tracker with pending tasks, recent submissions, leaderboard.
- **Profile Page**: (`/profile`) displays user rankings, XP, and statistics.
- **UI**: Consistent design with buttons, inputs, modals, and form components.

## Suggested Next Steps

### Priority 1: Backend XP Awarding ⏳ IN QUEUE
Currently, XP is awarded from the frontend after verification. This should be moved to a trusted server-side path.
1. Create a server-side route (e.g., `/api/award-xp`) that calls `public.award_xp()`
2. Move XP awarding logic from frontend to this new endpoint
3. Frontend should call this endpoint only after verification is complete
4. Validate user ID and reason on the server before calling the function

### Other Suggested Next Steps (Lower Priority)
1. **Verification Provider Assessment**: Assess VisionSter API's privacy and reliability before production.
2. **Verification Retry**: Allow users to retry verification for failed/rejected submissions.
3. **Loading States**: Enhance UI with more granular loading states during verification.
4. **Write Tests**: Add unit and integration tests for critical functions.
5. **Prepare for Deployment**: Configure Vercel environment variables and validate production build.
6. **Monitor Usage**: Add logging for verification requests and responses to monitor reliability and costs.

## Working Conventions

- Inspect existing files and preserve user changes; make the smallest focused change that fits the repository.
- Protect Supabase Row Level Security. Never put the service-role/secret key in a `NEXT_PUBLIC_` variable or browser code.
- Prefer server-side handling for privileged operations, including XP awards and external verification calls. Keep private API credentials server-only.
- Run the narrowest relevant checks after changes; app scripts are in `web/`.