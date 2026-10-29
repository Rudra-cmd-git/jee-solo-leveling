# JEE Solo Leveling Web App

This folder contains the Next.js application. Run app commands from `web/`.

## Run locally

```bash
npm install
npm run dev
```

Open http://localhost:3000. Checks: `npm run build` (production build), `npm run lint`, `npm run typecheck`, `npm test` (Vitest).

Copy `.env.example` to `.env.local` and set `NEXT_PUBLIC_SUPABASE_URL` + `NEXT_PUBLIC_SUPABASE_ANON_KEY` for Supabase access. For AI verification and XP awards also set the server-only `SUPABASE_SERVICE_ROLE_KEY` and `ANTHROPIC_API_KEY`. Apply both SQL migrations in `../supabase/migrations/` first (see `../SUPABASE_SETUP.md`). Never commit `.env.local`, and never expose service-role keys in `NEXT_PUBLIC_` variables.

For a file-by-file directory map, see [`../FILE_GUIDE.md`](../FILE_GUIDE.md). The root [README](../README.md) describes the product and database setup.
