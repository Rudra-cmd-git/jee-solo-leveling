# Project File Guide

This is the file-by-file map for JEE Solo Leveling. The layout is grouped by responsibility: project docs at the root, database assets under `supabase/`, and the Next.js app under `web/`. Keep Next.js route files inside `web/src/app/` so the App Router continues to discover them.

## Repository root

| File or folder | What it does and why it exists |
| --- | --- |
| `.gitignore` | Excludes local secrets, dependencies, build output, caches, and other generated files from Git. |
| `CLAUDE.md` | Project handoff: current implementation status, next steps, and security conventions for coding assistants. |
| `README.md` | Product overview, game-loop description, setup/env instructions, and roadmap. |
| `SUPABASE_SETUP.md` | Instructions for applying and configuring the Supabase schema (migrations 001 + 002). |
| `FILE_GUIDE.md` | This map; explains the purpose of maintained project files and where new files belong. |
| `docs/blueprint.pdf` | Original product blueprint and reference requirements. |
| `supabase/migrations/001_init_schema.sql` | Initial schema: users/tasks/submissions/xp_log, indexes, Row Level Security policies, timestamp triggers, secure XP award function. |
| `supabase/migrations/002_refurbishment.sql` | Profile auto-creation trigger, leaderboard view, anti-cheat column locks, 500-XP task cap, rank/streak logic in `award_xp()`, submission notes columns, private `proofs` storage bucket + policies. |
| `web/` | The runnable Next.js application; install dependencies and run npm scripts from this directory. |

## Web application

| File or folder | What it does and why it exists |
| --- | --- |
| `web/AGENTS.md` | Next.js-specific agent instructions, including the requirement to consult the installed version's local docs before coding. |
| `web/CLAUDE.md` | Points coding assistants to `AGENTS.md` for the web app's framework instructions. |
| `web/.gitignore` | App-level ignores for Next.js output, dependencies, environment files, and local development artifacts. |
| `web/.env.example` | Template for local environment variables (public Supabase values + server-only secrets). Copy to `.env.local`. |
| `web/.env.local` | Local environment variables for development. Ignored by Git; never commit real secrets. |
| `web/README.md` | Web app install, run, lint, and build instructions. |
| `web/package.json` | Web app dependencies and npm scripts (`dev`, `build`, `start`, `lint`, `typecheck`, `test`). |
| `web/package-lock.json` | Exact dependency resolution for repeatable npm installs in the web app. |
| `web/next.config.ts` | Next.js configuration, including the app's Turbopack root. |
| `web/next-env.d.ts` | Next.js-generated TypeScript declarations for framework types. |
| `web/tsconfig.json` | TypeScript compiler settings and the `@/*` import alias for `src/`. |
| `web/eslint.config.mjs` | ESLint configuration using the Next.js Core Web Vitals and TypeScript rules. |
| `web/tailwind.config.cjs` | Tailwind v3 theme: System colors (background/foreground/primary/secondary/accent + rank colors), fonts, glow/glass shadows, animations. |
| `web/postcss.config.mjs` | PostCSS pipeline (Tailwind + Autoprefixer). |
| `web/public/` | Static assets served directly from the site root (currently empty; favicon lives in `src/app/`). |
| `web/src/app/` | App Router route pages, API routes, shared root layout, and app-wide styles. |
| `web/src/app/layout.tsx` | Root HTML document, self-hosted fonts (Fontsource Inter + Orbitron), metadata, `AuthProvider` + `ToastProvider` wrappers. |
| `web/src/app/globals.css` | Tailwind layers + System component styles (glass panels, rank badges, XP bar, stat cards, skeletons). |
| `web/src/app/page.tsx` | Dashboard at `/`: player status, stat cards, active quests, recent proofs, top-10 leaderboard, quest/proof modals. |
| `web/src/app/profile/page.tsx` | Player page at `/profile`: editable name, rank ladder, quest/proof stats, XP ledger + recent XP history. |
| `web/src/app/sign-in/page.tsx` | Sign-in form at `/sign-in` (System-themed, show/hide password). |
| `web/src/app/sign-up/page.tsx` | Account creation at `/sign-up` (player name becomes the leaderboard name). |
| `web/src/app/api/submissions/verify/route.ts` | **Server-only** proof verification: validates the caller's token, sends the proof image to Claude Vision, and on approval awards XP via `award_xp()` with the service-role client. Degrades to `pending` if keys are unset. |
| `web/src/app/favicon.ico` | Browser tab and bookmark icon. |
| `web/src/components/` | Shared components used across routes. |
| `web/src/components/AppHeader.tsx` | Sticky app header: branding, primary nav with active state, XP/rank/player chip, and working client-side logout. |
| `web/src/components/AuthShell.tsx` | Shared "System window" chrome for the sign-in/sign-up pages. |
| `web/src/components/ConfigBanner.tsx` | Explains how to fix setup when Supabase env vars are missing. |
| `web/src/components/CreateTaskModal.tsx` | Create-quest form (subject select, difficulty XP presets, 1–500 cap) with toast + parent refetch callback. |
| `web/src/components/SubmissionModal.tsx` | Proof submission: photo upload to the `proofs` bucket with preview (or image URL), description, then calls the verify API and shows the verdict. |
| `web/src/components/ui/` | Shared presentational UI (design system). |
| `web/src/components/ui/button.tsx` | Button with variants/sizes and an `isLoading` spinner state. Defaults to `type="button"` so it never submits forms by accident. |
| `web/src/components/ui/input.tsx` | Styled text input. |
| `web/src/components/ui/card.tsx` | Bordered card container. |
| `web/src/components/ui/avatar.tsx` | Player avatar: image when provided, deterministic initials otherwise. |
| `web/src/components/ui/modal.tsx` | Accessible modal dialog (portal, Escape/overlay close, scroll lock, ARIA labels). |
| `web/src/components/ui/toast.tsx` | Toast provider + `useToast()` hook for System-style notifications. |
| `web/src/components/ui/system-panel.tsx` | Glass `[TITLE]` panel used to frame dashboard/profile sections. |
| `web/src/components/ui/xp-bar.tsx` | Animated XP progress bar toward the next rank. |
| `web/src/components/ui/rank-badge.tsx` | Color-coded E–S rank badge. |
| `web/src/components/ui/stat-card.tsx` | Stat tile (label, big Orbitron value, sublabel, icon). |
| `web/src/components/ui/skeleton.tsx` | Loading shimmer block. |
| `web/src/components/ui/index.ts` | Barrel exports for the UI kit. |
| `web/src/lib/` | Shared clients, domain types, and helpers. |
| `web/src/lib/supabase.ts` | Browser Supabase client; never throws on missing env (exports `isSupabaseConfigured`). |
| `web/src/lib/supabase-admin.ts` | **Server-only** service-role + token-validation clients. Never import from Client Components. |
| `web/src/lib/auth.ts` | Supabase sign-in/sign-up/sign-out/user helpers and auth-change listener. |
| `web/src/lib/auth-context.tsx` | Client React context exposing `{ user, loading, configured }`; renders children immediately (pages own their loading states). |
| `web/src/lib/profile.ts` | `ensureProfile()` — fetches the `public.users` row, creating it if the DB trigger has not run yet. |
| `web/src/lib/types.ts` | Domain types: `Profile`, `Task`, `Submission`, `LeaderboardEntry`, `XpLogEntry`. |
| `web/src/lib/utils.ts` | `cn()`, rank thresholds/progress math (`MAX_TASK_XP`, `RANK_THRESHOLDS` — keep in sync with migration 002), number/date formatting. |
| `web/src/lib/utils.test.ts` | Vitest unit tests for the rank math (`npm test`). |

## Local-only and generated folders

`web/node_modules/` contains installed packages and is recreated by `npm install`. `web/.next/` contains generated Next.js build and development output. Neither belongs in the maintained source tree or should be edited by hand. `.env.local` stays local and must not be committed.

## Where to put new files

- Product and setup documentation: repository root or `docs/` for reference material.
- Database changes: a new, numbered SQL migration under `supabase/migrations/`.
- Pages and route handlers: `web/src/app/` using the App Router folder convention.
- Reusable UI: `web/src/components/` (generic primitives belong in `web/src/components/ui/`).
- Shared clients and domain helpers: `web/src/lib/`.
- Publicly served static assets: `web/public/`.
