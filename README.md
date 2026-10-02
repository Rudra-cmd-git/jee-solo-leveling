# JEE Solo Leveling System

A gamified study tracker for JEE prep — leaderboard, XP, ranks, and AI-verified proof-of-work.

## Stack
- **Frontend:** Next.js (React)
- **Backend/DB/Auth:** Supabase
- **AI Verification:** Claude API (vision)
- **Hosting:** Vercel

## Team
- Person A: Product & Interface
- Person B: Data & Intelligence

## Build Order
1. Project setup + login
2. Task creation + XP logic
3. Photo upload + Claude verification
4. Leaderboard
5. Polish & deploy

## Directory Structure
```
jee-solo-leveling/
├── docs/                     # Documentation and references
│   └── blueprint.pdf         # Original project blueprint
├── supabase/                 # Database configuration
│   └── migrations/           # SQL migration files
│       └── 001_init_schema.sql
├── web/                      # Next.js application
│   ├── src/app/               # App Router pages and styles
│   ├── src/lib/               # Shared clients and utilities
│   ├── package.json
│   └── .env.local             # Local environment variables (NOT committed)
├── .gitignore                # Git ignore rules
├── CLAUDE.md                 # AI assistant handoff notes
├── README.md                 # This file
└── SUPABASE_SETUP.md         # Detailed Supabase setup instructions
```

## Getting Started

The Next.js app and its npm scripts are in `web/`. Run these commands from the repository root:

```bash
cd web
npm install
npm run dev
```

Open http://localhost:3000. To create a production build, run `npm run build` from `web/`.

Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` in `web/.env.local` for Supabase features. Never put the service-role key in a `NEXT_PUBLIC_` variable.

## Database Schema
The Supabase migration has created:
- **users**: Profile data (extends auth.users)
- **tasks**: Study tasks/daily quests
- **submissions**: Proof submissions with photo URLs
- **xp_log**: Immutable XP transaction ledger
- **Row Level Security**: Enabled on all tables
- **Secure XP Function**: `public.award_xp()` prevents client-side manipulation

## Next Steps
1. Implement authentication flow
2. Build task creation and submission interfaces
3. Add photo upload to Supabase Storage
4. Integrate server-side proof verification
5. Build the leaderboard

## Important Notes
- **Never commit** `.env.local` - it contains your public keys
- **Never expose** the Supabase service_role key in client code
- All privileged operations (XP awards, Claude API calls) should be handled server-side
- Row Level Security ensures users can only access their own data
