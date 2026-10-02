# JEE Solo Leveling System

A gamified study tracker for JEE prep — leaderboard, XP, ranks, and AI-verified proof-of-work.

## Stack
- **Frontend:** Next.js (React)
- **Backend/DB/Auth:** Supabase
- **AI Verification:** VisionSter image analysis (current integration)
- **Hosting:** Vercel

## Team
- Person A: Product & Interface
- Person B: Data & Intelligence

## Current Status
✅ **Database Schema**: Supabase schema, RLS policies, and restricted XP award function are defined in the migration.
✅ **Application**: The runnable Next.js app is in `web/`.
✅ **Authentication**: Supabase sign-up, sign-in, session handling, and sign-out are implemented.
✅ **Study Tracker**: Users can create tasks, submit image URLs for proof verification, view XP/rank progress, and see the leaderboard and profile statistics.
✅ **Verification Flow**: Proof submissions are sent through `/api/verify-submission`, which forwards the image URL to VisionSter for analysis.
⏳ **Remaining**: Review third-party proof-image handling, replace proof URL entry with storage upload, move XP awarding to a trusted server-side path, add automated tests, and prepare deployment configuration.

## Build Order (Following Blueprint)
1. Replace proof image URL entry with Supabase Storage uploads.
2. Add automated tests for verification and XP awarding.
3. Verify the end-to-end flow with the configured Supabase and verification services.
4. Review verification-provider data handling and configure deployment.

## Directory Structure
```
jee-solo-leveling/
├── docs/                     # Documentation and references
│   └── blueprint.pdf         # Original project blueprint
├── supabase/                 # Database configuration
│   └── migrations/           # SQL migration files
│       └── 001_init_schema.sql
├── web/                      # Next.js application
│   ├── src/app/               # Dashboard, auth, profile, API routes, and styles
│   ├── src/components/        # Task/submission flows and reusable UI
│   ├── src/lib/               # Supabase client, auth, and utilities
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
1. Add actual image uploads to Supabase Storage; the current submission flow accepts an image URL.
2. Add tests for the verification route and XP-award flow.
3. Run and document an end-to-end test against the configured services.
4. Configure deployment environment variables and deploy.

## Important Notes
- **Never commit** `.env.local` - it contains your public keys
- **Never expose** the Supabase service_role key in client code
- All privileged operations (XP awards, Claude API calls) should be handled server-side
- Row Level Security ensures users can only access their own data