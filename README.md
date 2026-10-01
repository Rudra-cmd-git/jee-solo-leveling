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

## Current Status
✅ **Database Schema**: Supabase migration applied (users, tasks, submissions, xp_log tables with RLS)
✅ **Environment Setup**: `.env.local` template configured with project URL
⏳ **Application Scaffold**: Next.js app not yet initialized
⏳ **Authentication**: Supabase Auth not yet implemented
⏳ **Core Features**: Task creation, photo upload, XP system, leaderboard not yet built

## Build Order (Following Blueprint)
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
├── .env.example              # Template for environment variables
├── .env.local                # Environment variables (NOT committed)
├── .gitignore                # Git ignore rules
├── CLAUDE.md                 # AI assistant handoff notes
├── README.md                 # This file
└── SUPABASE_SETUP.md         # Detailed Supabase setup instructions
```

## Getting Started

### 1. Configure Environment Variables
1. Get your Supabase **anon public key** from:
   - Supabase Dashboard → Settings → API
2. Update `.env.local`:
   ```env
   NEXT_PUBLIC_SUPABASE_URL=https://gdgeqiipxmvckvtvmbns.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your-actual-anon-key-here
   ```

### 2. Initialize Next.js Application
```bash
npx create-next-app@latest .
npm install @supabase/supabase-js
```

### 3. Set Up Supabase Client
Create `lib/supabase.js`:
```javascript
import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
)
```

### 4. Implement Authentication
- Create login/signup pages using Supabase Auth
- Protect routes with authentication checks
- Create user profile component reading from `users` table

## Database Schema
The Supabase migration has created:
- **users**: Profile data (extends auth.users)
- **tasks**: Study tasks/daily quests
- **submissions**: Proof submissions with photo URLs
- **xp_log**: Immutable XP transaction ledger
- **Row Level Security**: Enabled on all tables
- **Secure XP Function**: `public.award_xp()` prevents client-side manipulation

## Next Steps
1. Verify `.env.local` has your actual Supabase anon key
2. Initialize the Next.js app as shown above
3. Begin implementing authentication flow
4. Build task creation interface
5. Add photo upload to Supabase Storage
6. Integrate Claude API for proof verification

## Important Notes
- **Never commit** `.env.local` - it contains your public keys
- **Never expose** the Supabase service_role key in client code
- All privileged operations (XP awards, Claude API calls) should be handled server-side
- Row Level Security ensures users can only access their own data