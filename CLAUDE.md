# Claude Code Project Handoff

Read this file at the start of each session, then verify important status against the repository before making changes. Keep the **Current Status** section up to date when meaningful work is completed. Never put passwords, API keys, tokens, or other secrets in this file or commit them.

## Project

JEE Solo Leveling is a gamified JEE study tracker: quests (tasks), photo proof submissions, AI verification, XP, ranks E→S, streaks, and a leaderboard.

Stack:
- Next.js 16 + React 19 + Tailwind CSS 3 (the app lives in `web/`)
- Supabase for database, authentication, and file storage
- Claude Vision (Anthropic API) called only from the server route `web/src/app/api/submissions/verify/route.ts`
- Vercel for hosting

## Current Status

Updated: 2026-10-29 (refurbishment pass)

- **The app builds and runs.** `npm run build`, `npm run lint`, `npm run typecheck`, and `npm test` (Vitest, rank-math unit tests) are all green. It also builds with no env vars set — the UI shows a "Supabase is not configured" banner instead of crashing (see `web/.env.example`).
- Pages: dashboard `/` (player status, stat cards, active quests, recent proofs, top-10 leaderboard), `/profile` (editable player name, rank ladder, stats, XP history), `/sign-in`, `/sign-up`. All share the Solo Leveling design system in `web/src/components/ui/` (SystemPanel, XPBar, RankBadge, StatCard, accessible Modal, toast provider) plus `AppHeader` with working client-side logout. The old broken server-side `/logout` route was removed deliberately: auth is browser-session based.
- Fonts are self-hosted via `@fontsource-variable/*` (Inter + Orbitron) so builds never depend on Google Fonts.
- **Core loop is wired end to end:** create quest (XP capped at 500) → submit photo proof to the private Supabase Storage bucket `proofs` (or paste an image URL; description is saved) → client calls `POST /api/submissions/verify` with the session token → route verifies with Claude Vision → on approval calls `award_xp()` with the service-role client, marks quest approved. Without `SUPABASE_SERVICE_ROLE_KEY`/`ANTHROPIC_API_KEY` the submission stays `pending` with an explanatory message.
- **Database needs migration 002 applied** (`supabase/migrations/002_refurbishment.sql`) on top of 001: auto-creates `public.users` rows on sign-up (plus `lib/profile.ts` client fallback), adds streak columns + submission `description`/`ai_notes`, caps task XP, locks XP/rank/verdict columns from client edits, recomputes rank + streak inside `award_xp()`, adds the `leaderboard` view (leaderboard previously could only return the current user under RLS), and creates the `proofs` bucket with per-player folder policies. Client code degrades gracefully (fallbacks) if 002 is not applied yet.
- Rank thresholds live in two places that must stay in sync: `RANK_THRESHOLDS`/`MAX_TASK_XP` in `web/src/lib/utils.ts` and the CASE/check in migration 002.
- Known architecture note: auth uses `@supabase/supabase-js` browser sessions (localStorage), so there is no Next.js middleware protection; pages guard + redirect client-side. Migrating to `@supabase/ssr` cookie sessions is the planned hardening step.

## Suggested Next Steps

1. Apply migration 002 in Supabase and set the server env vars, then test the full loop with a real account + photo.
2. Deploy to Vercel (set the same env vars there).
3. Migrate auth to `@supabase/ssr` for middleware route protection.
4. Product features: daily quests/penalties, guilds, notifications.

## Working Conventions

- Inspect existing files and preserve user changes; make the smallest focused change that fits the repository.
- Protect Supabase Row Level Security. Never put the service-role/secret key in a `NEXT_PUBLIC_` variable or browser code. `web/src/lib/supabase-admin.ts` is server-only — never import it from a Client Component.
- Prefer server-side handling for privileged operations, including XP awards and Claude API calls. Keep private API credentials server-only.
- After changes run the checks from `web/`: `npm run typecheck`, `npm run lint`, `npm test`, `npm run build`.
- Keep this handoff, `README.md`, and `FILE_GUIDE.md` in sync when structure or status changes.
