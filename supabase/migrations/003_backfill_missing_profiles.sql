-- Migration: Backfill missing user profiles
-- Purpose: Ensure all existing auth.users have corresponding public.users records
-- Date: 2026-10-03

-- This migration safely backfills profiles for any auth users that don't have a public.users row.
-- It only creates profiles for users without one and preserves any existing data.

INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
SELECT
    au.id,
    COALESCE(
        NULLIF(btrim(au.raw_user_meta_data->>'name'), ''),
        'Studier'
    ),
    'E',
    0,
    COALESCE(au.created_at, NOW()),
    NOW()
FROM auth.users au
WHERE NOT EXISTS (
    SELECT 1 FROM public.users pu WHERE pu.id = au.id
)
ON CONFLICT (id) DO NOTHING;

-- Verify the backfill
-- SELECT COUNT(*) as total_auth_users FROM auth.users;
-- SELECT COUNT(*) as total_profiles FROM public.users;
-- These counts should match after this migration.
