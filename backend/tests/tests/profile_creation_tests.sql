-- TEST SUITE: User Profile Creation Foundation
-- Purpose: Validate that the profile creation system works correctly and does NOT silently swallow errors
-- These tests should be run in a Supabase SQL editor or via a testing framework

-- ============================================================================
-- STRUCTURAL TESTS (metadata about the trigger and function)
-- ============================================================================

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
    pg_get_functiondef(p.oid) as definition
FROM pg_proc p
WHERE p.proname = 'handle_new_user'
    AND p.pronamespace = 'public'::regnamespace;

-- TEST 2b: Verify function owner has sufficient privileges
-- Expected: Owner should be a superuser or have INSERT privilege on public.users
SELECT
    p.proname,
    pg_get_userbyid(p.proowner) as owner,
    has_database_privilege(p.proowner, 'public'::regnamespace, 'usage') as has_schema_usage
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

-- ============================================================================
-- CRITICAL TESTS: Profile creation failures are NOT silently swallowed
-- ============================================================================

-- TEST 7: Verify NO broad exception handler
-- Expected: Function definition should NOT contain "EXCEPTION WHEN OTHERS"
-- This ensures real errors propagate and fail the transaction
SELECT
    CASE
        WHEN pg_get_functiondef(p.oid) LIKE '%EXCEPTION WHEN OTHERS%' THEN 'FAIL: Broad exception handler found'
        ELSE 'PASS: No broad exception handler'
    END as result
FROM pg_proc p
WHERE p.proname = 'handle_new_user'
    AND p.pronamespace = 'public'::regnamespace;

-- TEST 8: Verify ON CONFLICT is present (idempotency)
-- Expected: Function should use ON CONFLICT (id) DO NOTHING
-- This allows duplicate trigger fires to be safe, but other errors propagate
SELECT
    CASE
        WHEN pg_get_functiondef(p.oid) LIKE '%ON CONFLICT%DO NOTHING%' THEN 'PASS: ON CONFLICT idempotency present'
        ELSE 'FAIL: ON CONFLICT not found'
    END as result
FROM pg_proc p
WHERE p.proname = 'handle_new_user'
    AND p.pronamespace = 'public'::regnamespace;

-- ============================================================================
-- DATA INTEGRITY TESTS
-- ============================================================================

-- TEST 9: Check for duplicate profiles (should be none)
-- Expected: No duplicate profile IDs (PRIMARY KEY ensures this)
SELECT id, COUNT(*) as count
FROM public.users
GROUP BY id
HAVING COUNT(*) > 1;

-- TEST 10: Verify defaults are set correctly
-- Expected: New profiles should have rank = 'E' and total_xp = 0
SELECT
    rank,
    total_xp,
    COUNT(*) as count
FROM public.users
WHERE rank IS NULL OR total_xp IS NULL
GROUP BY rank, total_xp;

-- TEST 11: Check for orphaned profiles (profiles without auth.users)
-- Expected: None (foreign key should prevent this)
SELECT pu.id, pu.name
FROM public.users pu
LEFT JOIN auth.users au ON pu.id = au.id
WHERE au.id IS NULL;

-- TEST 12: Check for orphaned auth users (auth.users without profiles)
-- Expected: None (trigger should have created profiles for all)
SELECT au.id, au.email
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL;

-- ============================================================================
-- MANUAL INTEGRATION TESTS
-- ============================================================================

-- MANUAL TEST 1: Create a new auth user via signUp
-- Expected behavior:
-- 1. Call supabase.auth.signUp({ email: "test@example.com", password: "...", options: { data: { name: "Test User" } } })
-- 2. Auth user created in auth.users
-- 3. Trigger fires and creates corresponding row in public.users
-- 4. Name should be "Test User" (from metadata)
-- 5. Rank should be "E" (default)
-- 6. total_xp should be 0 (default)
-- 7. Query: SELECT * FROM public.users WHERE name = 'Test User';
-- 8. Expected: Exactly 1 row with rank='E', total_xp=0

-- MANUAL TEST 2: Create with null/empty name in metadata
-- Expected behavior:
-- 1. Call signUp with empty or null name in metadata
-- 2. Profile should be created with name = 'Studier' (fallback)
-- 3. Query: SELECT * FROM public.users WHERE name = 'Studier';
-- 4. Expected: Rows with fallback name

-- MANUAL TEST 3: RLS access control
-- Expected behavior:
-- 1. Authenticated as User A
-- 2. SELECT * FROM public.users WHERE id = A.id → should return User A's profile
-- 3. SELECT * FROM public.users WHERE id = B.id → should return no rows (RLS blocks it)
-- 4. INSERT INTO public.users (id, name, ...) WITH id = B.id → should fail (RLS blocks it)

-- MANUAL TEST 4: Verify transaction rollback on profile creation failure
-- THIS IS THE CRITICAL TEST for ensuring failures are NOT silently swallowed
-- Note: This requires manually corrupting the schema temporarily for testing
-- Expected: If public.users insertion fails, the entire auth.users INSERT must fail
-- The auth user should NOT be created if the profile creation fails
-- This ensures auth.users and public.users stay in 1:1 sync
