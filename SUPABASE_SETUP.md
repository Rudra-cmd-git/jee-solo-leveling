# Supabase Database Setup for JEE Solo Leveling System

## Overview
This document explains how to set up the Supabase database foundation for the JEE Solo Leveling System, including:
- User profiles table
- Study tasks table
- Proof submissions table
- XP ledger table
- Appropriate foreign keys and Row Level Security (RLS) policies
- Security measures to prevent client-side XP manipulation

## Files Created

### 1. Migration Script
`supabase/migrations/001_init_schema.sql` - Contains the complete schema setup

### 2. Setup Instructions
This file (`SUPABASE_SETUP.md`)

## Database Schema

### Tables Created

#### `public.users`
- Extends Supabase `auth.users` table
- Fields: `id` (UUID, PK, FK to auth.users), `name`, `rank` (E-S), `total_xp`, timestamps
- RLS: Users can only view/update their own profile

#### `public.tasks`
- Study tasks/daily quests
- Fields: `id` (UUID, PK), `user_id` (FK to users), `title`, `subject`, `xp_value`, `status`, timestamps
- RLS: Users can only manage their own tasks

#### `public.submissions`
- Proof submissions (photo uploads)
- Fields: `id` (UUID, PK), `task_id` (FK to tasks), `photo_url`, `ai_verdict`, timestamps
- RLS: Users can only view/submit/update submissions for their own tasks

#### `public.xp_log`
- XP ledger for tracking all XP changes
- Fields: `id` (UUID, PK), `user_id` (FK to users), `xp_change`, `reason`, `created_at`
- RLS: Users can only view their own XP log
- **Security**: Direct updates/deletes are blocked; XP must be awarded via secure function

## Security Features

### Row Level Security (RLS)
All tables have RLS enabled with policies ensuring:
- Users can only access their own data
- No cross-user data leakage

### XP Manipulation Prevention
To prevent clients from editing or duplicating XP awards:
1. **Direct table modifications blocked**: UPDATE and DELETE policies on `xp_log` return false
2. **Secure function-only access**: XP can only be awarded via the `public.award_xp()` function
3. **Function security**: The function uses `SECURITY DEFINER` to run with table owner privileges
4. **Atomic updates**: XP log entry and user total_xp update happen in single transaction

### How to Apply the Migration

### Connect this repository to your Supabase project

1. In the Supabase dashboard, open **Project Settings > API** (or **Data API**) and copy the Project URL and the publishable key. For older projects, use the `anon` key. Do not use or expose the `service_role` / secret key in browser code.
2. In the repository root, copy `.env.example` to `.env.local` and fill in those values. `.env.local` is ignored by Git; do not commit it.
3. Apply the database schema using either method below. The SQL Editor is the simplest option for this repository as it currently has the migration but not a Next.js app or Supabase CLI configuration.

Once a Next.js app is added, install `@supabase/supabase-js` and create its client using `process.env.NEXT_PUBLIC_SUPABASE_URL` and `process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY`. These public credentials are protected by the database's Row Level Security policies; never put privileged service-role credentials in a `NEXT_PUBLIC_` variable.

#### Option 1: Using Supabase CLI
1. Install Supabase CLI: `npm install -g supabase`
2. Login: `supabase login`
3. Link to your project: `supabase link --project-ref YOUR_PROJECT_REF`
4. Start Supabase (if using local): `supabase start`
5. Apply migration: `supabase db push`

#### Option 2: Using Supabase Dashboard
1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Create a new query
4. Copy and paste the entire contents of `supabase/migrations/001_init_schema.sql`
5. Run the query

#### Option 3: Using psql (if you have direct DB access)
```bash
psql "postgresql://postgres:[YOUR_PASSWORD]@db.[YOUR_PROJECT_REF].supabase.co:5432/postgres" -f supabase/migrations/001_init_schema.sql
```

## Using the Secure XP Function

Instead of directly inserting into `xp_log` or updating `users.total_xp`, applications should call:

```sql
SELECT public.award_xp(
    'user-uuid-here',  -- p_user_id
    50,                -- p_xp_change (positive or negative)
    'Completed Physics task'  -- p_reason
);
```

This ensures:
- XP changes are logged immutably
- User total XP is updated atomically
- No client can bypass the validation logic
- All XP changes are auditable via the `xp_log` table

## Next Steps

After setting up the database:
1. Set up Supabase client in your Next.js application
2. Implement authentication flow
3. Create APIs/services that use the `award_xp` function for XP awards
4. Build the UI components for task creation, submission, and leaderboard
5. Integrate Claude API vision for proof verification

## Important Notes

- The `rank` field uses a CHECK constraint to ensure only valid Solo Leveling ranks (E-S) are used
- All foreign keys use `ON DELETE CASCADE` for clean data removal
- Timestamps are set automatically with DEFAULT and trigger functions
- The system is designed for the initial MVP as described in the blueprint
- Feel free to adjust XP values, rank names, or add additional fields as needed for V2

## Troubleshooting

If you encounter permission errors:
1. Ensure you're running the migration as a user with sufficient privileges (supabase admin role)
2. Check that the auth schema exists (it should by default in Supabase projects)
3. Verify that the uuid-ossp extension is available in your database

For RLS testing:
1. Create test users in Supabase Auth
2. Use `SET LOCAL ROLE` or switch user context in SQL editor to test policies
3. Verify that users can only access their own data