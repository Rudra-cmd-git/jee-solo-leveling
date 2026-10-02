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

Updated: 2026-10-01

- The user reports that they have created a Supabase project and shared the public project URL.
- The runnable Next.js app and npm manifest are in `web/`; run npm commands from that directory.
- `web/.env.local` is present. Do not expose or copy its values into documentation.
- `npm run build` succeeds from `web/`; the homepage is currently the default Next.js starter page.
- The SQL migration is at `supabase/migrations/001_init_schema.sql`. Setup instructions are in `SUPABASE_SETUP.md`.
- The `public.award_xp()` function has been tightened so authenticated users can only award XP to themselves, and execute permission is restricted to the trusted `service_role` path rather than regular authenticated clients.
- The immediate next step is replacing the starter homepage with the study tracker experience, then wiring authentication and server-side task verification.

## Suggested Next Steps

1. Confirm whether the Supabase migration is applied; do not ask the user to paste secret values into chat.
2. Implement authentication and verify `award_xp()` grants before enabling XP awards.
3. Build task and submission flows, then server-side proof verification and leaderboard functionality.
4. Update this handoff as the implementation state changes, including decisions, completed milestones, and the next concrete task.

## Working Conventions

- Inspect existing files and preserve user changes; make the smallest focused change that fits the repository.
- Protect Supabase Row Level Security. Never put the service-role/secret key in a `NEXT_PUBLIC_` variable or browser code.
- Prefer server-side handling for privileged operations, including XP awards and Claude API calls. Keep private API credentials server-only.
- Run the narrowest relevant checks after changes. Since there is no app/package setup yet, confirm the available validation commands before trying npm scripts.
