-- TEST SUITE: User Profile Creation Foundation
-- Purpose: Validate that the profile creation system works correctly
-- These tests should be run in a Supabase SQL editor or via a testing framework

-- TEST 1: Verify trigger exists and is enabled
-- Expected: Trigger should be listed in information_schema
SELECT
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created'
    AND event_object_table = 'users'
    AND event_object_schema = 'auth';

-- TEST 2: Verify function exists with correct settings
-- Expected: Function should exist with SECURITY DEFINER and search_path set
SELECT
    p.proname,
    p.prosecdef,
    pg_get_functiondef(p.oid)
FROM pg_proc p
WHERE p.proname = 'handle_new_user'
    AND p.pronamespace = 'public'::regnamespace;

-- TEST 3: Verify foreign key constraint
-- Expected: public.users.id should have FK to auth.users.id with ON DELETE CASCADE
SELECT
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS referenced_table,
    ccu.column_name AS referenced_column,
    rc.update_rule,
    rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
JOIN information_schema.referential_constraints rc ON tc.constraint_name = rc.constraint_name
WHERE tc.table_name = 'users'
    AND tc.table_schema = 'public'
    AND tc.constraint_type = 'FOREIGN KEY';

-- TEST 4: Verify RLS is enabled
-- Expected: RLS should be on for public.users
SELECT
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE tablename = 'users' AND schemaname = 'public';

-- TEST 5: Verify RLS policies exist
-- Expected: Should have SELECT, INSERT, UPDATE policies for own profile
SELECT
    policyname,
    permissive,
    roles,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'users' AND schemaname = 'public'
ORDER BY policyname;

-- TEST 6: Verify schema structure
-- Expected: All required columns should exist with correct types
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'users' AND table_schema = 'public'
ORDER BY ordinal_position;

-- TEST 7: Check for duplicate profiles (should be none)
-- Expected: No duplicate profile IDs
SELECT id, COUNT(*) as count
FROM public.users
GROUP BY id
HAVING COUNT(*) > 1;

-- TEST 8: Verify defaults are set
-- Expected: New profiles should have:
--   - rank = 'E' by default
--   - total_xp = 0 by default
SELECT
    rank,
    total_xp,
    COUNT(*) as count
FROM public.users
WHERE rank IS NULL OR total_xp IS NULL
GROUP BY rank, total_xp;

-- TEST 9: Check for orphaned profiles (profiles without auth.users)
-- Expected: None (foreign key should prevent this)
SELECT pu.id, pu.name
FROM public.users pu
LEFT JOIN auth.users au ON pu.id = au.id
WHERE au.id IS NULL;

-- TEST 10: Check for orphaned auth users (auth.users without profiles)
-- Expected: None after migration 003 runs
SELECT au.id, au.email
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL;

-- MANUAL TEST: Create a new auth user via signUp
-- Expected behavior:
-- 1. Call supabase.auth.signUp({ email: "test@example.com", password: "...", options: { data: { name: "Test User" } } })
-- 2. Auth user created in auth.users
-- 3. Trigger fires and creates corresponding row in public.users
-- 4. Name should be "Test User" (from metadata)
-- 5. Rank should be "E" (default)
-- 6. total_xp should be 0 (default)
-- 7. No profile should have been created by frontend code

-- MANUAL TEST: RLS access control
-- Expected behavior:
-- 1. Authenticated as User A
-- 2. SELECT * FROM public.users WHERE id = A.id → should return User A's profile
-- 3. SELECT * FROM public.users WHERE id = B.id → should return no rows (RLS blocks it)
-- 4. INSERT INTO public.users (id, name, ...) WITH id = B.id → should fail (RLS blocks it)

-- MANUAL TEST: Profile name with null/empty metadata
-- Expected behavior:
-- 1. Call signUp with empty or null name in metadata
-- 2. Profile should be created with name = 'Studier' (fallback)
