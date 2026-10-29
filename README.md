# JEE Solo Leveling System

A gamified study tracker for JEE prep — quests, photo proof-of-work, AI verification, XP, ranks (E → S), streaks, and a leaderboard.

## Stack
- **Frontend:** Next.js 16 (React 19, Tailwind CSS 3) in `web/`
- **Backend/DB/Auth/Storage:** Supabase (Postgres + RLS + Storage)
- **AI Verification:** Claude Vision via a server-only API route
- **Hosting:** Vercel

## Team
- Person A: Product & Interface
- Person B: Data & Intelligence

## How the game loop works
1. **Create a quest** — a study task with a subject and an XP value (capped at 500 by the database).
2. **Submit proof** — upload a photo of your work (stored in the private `proofs` bucket) or paste an image URL.
3. **The System verifies** — `POST /api/submissions/verify` sends the image to Claude Vision server-side. On approval it calls the locked-down `public.award_xp()` (service-role only), which writes the XP ledger, updates your total, **recomputes your rank**, and **extends your streak**. Rejected proof can be resubmitted.
4. **Rank up & climb** — XP thresholds E(0) → D(1,000) → C(2,500) → B(5,000) → A(10,000) → S(25,000), with a global top-10 leaderboard.

If `ANTHROPIC_API_KEY` or the service-role key is not set, submissions are stored as **pending** and the UI explains why — nothing crashes.

## Getting Started

### 1. Database
In the Supabase SQL Editor, run in order:
1. `supabase/migrations/001_init_schema.sql` — tables, RLS, `award_xp()`
2. `supabase/migrations/002_refurbishment.sql` — auto-create profile rows on sign-up, leaderboard view, anti-cheat column locks, XP cap, rank/streak inside `award_xp()`, private `proofs` storage bucket

See `SUPABASE_SETUP.md` for details.

### 2. Environment
```bash
cd web
cp .env.example .env.local   # then fill in your values
```
| Variable | Where | Purpose |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | browser-safe | Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | browser-safe | anon/publishable key (RLS protects data) |
| `SUPABASE_SERVICE_ROLE_KEY` | **server only** | lets the verify route award XP |
| `ANTHROPIC_API_KEY` | **server only** | enables Claude Vision verification |
| `ANTHROPIC_MODEL` | optional | defaults to `claude-sonnet-4-5` |

Never put the service-role key in a `NEXT_PUBLIC_` variable or commit `.env.local`.

### 3. Run
```bash
cd web
npm install
npm run dev        # http://localhost:3000
```

Checks: `npm run build` · `npm run lint` · `npm run typecheck` · `npm test` (Vitest unit tests for the rank math).

## Directory Structure
```
jee-solo-leveling/
├── docs/blueprint.pdf            # Original product blueprint
├── supabase/migrations/          # 001 (schema) + 002 (refurbishment)
├── web/                          # Next.js application
│   ├── src/app/                  # Pages: dashboard /, /profile, /sign-in, /sign-up
│   │   └── api/submissions/verify/  # Server-only AI verification route
│   ├── src/components/           # AppHeader, quest modals, ui/ design system
│   ├── src/lib/                  # Supabase clients, auth, types, rank utils
│   └── .env.local                # Local env vars (NOT committed)
├── CLAUDE.md                     # AI assistant handoff notes
├── FILE_GUIDE.md                 # File-by-file map
└── SUPABASE_SETUP.md             # Detailed database setup
```

## Security model
- Row Level Security on every table; players only ever touch their own rows.
- Column-level grants (migration 002) mean `total_xp`, `rank`, streak and `ai_verdict` **cannot be edited from the browser** — they change only inside `award_xp()` / the verify route under the service role.
- The leaderboard is a view exposing only name/XP/rank/streak.
- Proof photos live in a private bucket; each player can access only their own folder.

## Roadmap
- [x] Project setup, auth, profile auto-creation
- [x] Quest creation with XP caps and difficulty presets
- [x] Photo upload (Supabase Storage) + Claude Vision verification + XP/rank/streak awards
- [x] Leaderboard, profile stats, XP history
- [ ] Migrate auth to cookie sessions (`@supabase/ssr`) for middleware route protection
- [ ] Daily quest generation + penalties, guilds/friends, push notifications
- [ ] Deploy to Vercel
