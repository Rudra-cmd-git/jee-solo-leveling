# Project File Guide

This is the file-by-file map for JEE Solo Leveling. The existing layout is grouped by responsibility: project docs at the root, database assets under `supabase/`, and the Next.js app under `web/`. Keep Next.js route files inside `web/src/app/` so the App Router continues to discover them.

## Repository root

| File or folder | What it does and why it exists |
| --- | --- |
| `.gitignore` | Excludes local secrets, dependencies, build output, caches, and other generated files from Git. |
| `CLAUDE.md` | Project handoff: current implementation status, next steps, and security conventions for coding assistants. |
| `README.md` | Product overview, stack, setup commands, database summary, and project-level getting-started notes. |
| `SUPABASE_SETUP.md` | Instructions for applying and configuring the Supabase schema. |
| `FILE_GUIDE.md` | This map; explains the purpose of maintained project files and where new files belong. |
| `docs/blueprint.pdf` | Original product blueprint and reference requirements. |
| `supabase/migrations/001_init_schema.sql` | Initial database schema, indexes, Row Level Security policies, timestamp triggers, and secure XP award function. |
| `web/` | The runnable Next.js application; install dependencies and run npm scripts from this directory. |

## Web application

| File or folder | What it does and why it exists |
| --- | --- |
| `web/AGENTS.md` | Next.js-specific agent instructions, including the requirement to consult the installed version's local docs before coding. |
| `web/CLAUDE.md` | Points coding assistants to `AGENTS.md` for the web app's framework instructions. |
| `web/.gitignore` | App-level ignores for Next.js output, dependencies, environment files, and local development artifacts. |
| `web/.env.local` | Local environment variables for development. It is ignored by Git; never put secret values in documentation or client-visible variables. |
| `web/README.md` | Web app install, run, lint, and build instructions. |
| `web/package.json` | Web app dependencies and npm scripts (`dev`, `build`, `start`, `lint`). |
| `web/package-lock.json` | Exact dependency resolution for repeatable npm installs in the web app. |
| `web/next.config.ts` | Next.js configuration, including the app's Turbopack root. |
| `web/next-env.d.ts` | Next.js-generated TypeScript declarations for framework types. |
| `web/tsconfig.json` | TypeScript compiler settings and the `@/*` import alias for `src/`. |
| `web/eslint.config.mjs` | ESLint configuration using the Next.js Core Web Vitals and TypeScript rules. |
| `web/public/` | Static assets served directly from the site root. |
| `web/public/file.svg` | Starter template file illustration. |
| `web/public/globe.svg` | Starter template globe illustration. |
| `web/public/next.svg` | Next.js logo displayed by the current starter homepage. |
| `web/public/vercel.svg` | Vercel logo displayed by the current starter homepage. |
| `web/public/window.svg` | Starter template window illustration. |
| `web/src/app/` | App Router route pages, shared root layout, and app-wide styles. Keep route entry files in their route folders here. |
| `web/src/app/layout.tsx` | Root HTML document, shared font setup, metadata, and wrapper for all routes. |
| `web/src/app/globals.css` | Global reset and base styles shared across routes. |
| `web/src/app/page.tsx` | Authenticated study dashboard at `/`, including tasks, recent submissions, rank progress, and leaderboard. |
| `web/src/app/page.module.css` | Component-scoped styles for the homepage route. |
| `web/src/app/favicon.ico` | Browser tab and bookmark icon for the app. |
| `web/src/app/api/verify-submission/route.ts` | Server-side endpoint for proof image verification. |
| `web/src/app/sign-in/page.tsx` | Sign-in form route at `/sign-in`, connected to the Supabase auth helper. |
| `web/src/app/sign-up/page.tsx` | Account creation form route at `/sign-up`, connected to the Supabase auth helper. |
| `web/src/app/profile/page.tsx` | Profile route at `/profile`, showing rank progress, task/submission statistics, and XP history. |
| `web/src/app/logout/route.ts` | HTTP POST route that signs out and redirects to the sign-in page. |
| `web/src/app/logout/action.ts` | Server action for signing out and redirecting to the sign-in page. |
| `web/src/components/CreateTaskModal.tsx` | Modal for creating study tasks. |
| `web/src/components/SubmissionModal.tsx` | Submission form and client flow for saving proof and requesting verification. |
| `web/src/components/ui/` | Shared presentational UI components used by app routes. |
| `web/src/components/ui/avatar.tsx` | Avatar image component with size and fallback source handling. |
| `web/src/components/ui/button.tsx` | Reusable button styles and variants. |
| `web/src/components/ui/card.tsx` | Reusable bordered card container. |
| `web/src/components/ui/input.tsx` | Reusable styled input element. |
| `web/src/components/ui/modal.tsx` | Shared modal layout and content components. |
| `web/src/components/ui/index.ts` | Barrel exports for shared UI components. |
| `web/src/lib/` | Shared application helpers and service clients. |
| `web/src/lib/auth.ts` | Supabase sign-in, sign-up, sign-out, user lookup, profile update, and auth-change helpers. |
| `web/src/lib/auth-context.tsx` | Client React context for exposing the current user and auth loading state. |
| `web/src/lib/supabase.ts` | Browser Supabase client initialized from public environment variables. |
| `web/src/lib/utils.ts` | Rank thresholds, rank-progress calculations, number formatting, and date formatting helpers. |

## Local-only and generated folders

`web/node_modules/` contains installed packages and is recreated by `npm install`. `web/.next/` contains generated Next.js build and development output. Neither belongs in the maintained source tree or should be edited by hand. `.env.local` stays local and must not be committed.

## Where to put new files

- Product and setup documentation: repository root or `docs/` for reference material.
- Database changes: a new, numbered SQL migration under `supabase/migrations/`.
- Pages and route handlers: `web/src/app/` using the App Router folder convention.
- Reusable UI: `web/src/components/`.
- Shared clients and domain helpers: `web/src/lib/`.
- Publicly served static assets: `web/public/`.
