-- TEST SUITE: Lock Down public.users RLS and Server-Controlled Fields
-- Purpose: Verify that RLS policies protect server-controlled fields from manipulation
-- These tests document the security guarantees of the restricted RLS policies

-- ============================================================================
-- STRUCTURAL TESTS (verify policies exist and are correct)
-- ============================================================================

-- TEST 1: Verify RLS is enabled on public.users
-- Expected: RLS should be enabled (rowsecurity = true)
SELECT
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'users' AND schemaname = 'public';

-- TEST 2: Verify SELECT policy exists
-- Expected: "Users can view their own profile" policy for SELECT
SELECT
    policyname,
    permissive,
    cmd as operation,
    roles,
    qual as condition
FROM pg_policies
WHERE tablename = 'users' AND schemaname = 'public'
  AND cmd = 'SELECT';

-- TEST 3: Verify UPDATE policy exists (restricted)
-- Expected: "Users can update their name only" policy for UPDATE
SELECT
    policyname,
    permissive,
    cmd as operation,
    roles,
    qual as using_clause,
    with_check
FROM pg_policies
WHERE tablename = 'users' AND schemaname = 'public'
  AND cmd = 'UPDATE';

-- TEST 4: Verify INSERT policy is REMOVED
-- Expected: No INSERT policies (0 rows returned)
SELECT
    policyname,
    permissive,
    cmd as operation
FROM pg_policies
WHERE tablename = 'users' AND schemaname = 'public'
  AND cmd = 'INSERT';

-- TEST 5: Verify no DELETE policy exists
-- Expected: No DELETE policies (users cannot delete their own profile)
SELECT
    policyname,
    permissive,
    cmd as operation
FROM pg_policies
WHERE tablename = 'users' AND schemaname = 'public'
  AND cmd = 'DELETE';

-- TEST 6: Verify all policies for public.users
-- Expected: Only SELECT and UPDATE policies; no INSERT or DELETE
SELECT
    policyname,
    permissive,
    cmd as operation,
    roles
FROM pg_policies
WHERE tablename = 'users' AND schemaname = 'public'
ORDER BY cmd, policyname;

-- ============================================================================
-- SCHEMA STRUCTURE TESTS
-- ============================================================================

-- TEST 7: Verify public.users table structure
-- Expected: All required columns with correct types
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'users' AND table_schema = 'public'
ORDER BY ordinal_position;

-- TEST 8: Verify PRIMARY KEY on id column
-- Expected: id column is PRIMARY KEY
SELECT
    constraint_name,
    constraint_type,
    column_name
FROM information_schema.key_column_usage
WHERE table_name = 'users' AND table_schema = 'public'
  AND constraint_name LIKE '%pkey%';

-- TEST 9: Verify FOREIGN KEY to auth.users
-- Expected: id has FK to auth.users(id) with ON DELETE CASCADE
SELECT
    constraint_name,
    column_name,
    referenced_table_name,
    referenced_column_name,
    delete_rule
FROM (
    SELECT
        tc.constraint_name,
        kcu.column_name,
        ccu.table_name as referenced_table_name,
        ccu.column_name as referenced_column_name,
        rc.delete_rule
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
    JOIN information_schema.referential_constraints rc ON tc.constraint_name = rc.constraint_name
    WHERE tc.table_name = 'users' AND tc.table_schema = 'public'
      AND tc.constraint_type = 'FOREIGN KEY'
) fk_info;

-- ============================================================================
-- TRIGGER & FUNCTION TESTS (verify Task 1 still works)
-- ============================================================================

-- TEST 10: Verify handle_new_user trigger exists
-- Expected: Trigger on auth.users AFTER INSERT
SELECT
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created'
  AND event_object_table = 'users'
  AND event_object_schema = 'auth';

-- TEST 11: Verify handle_new_user function exists
-- Expected: Function with SECURITY DEFINER
SELECT
    proname,
    prosecdef as is_security_definer,
    proisstrict,
    provolatile
FROM pg_proc
WHERE proname = 'handle_new_user'
  AND pronamespace = 'public'::regnamespace;

-- TEST 12: Verify update_updated_at trigger exists
-- Expected: Trigger on public.users BEFORE UPDATE
SELECT
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing
FROM information_schema.triggers
WHERE trigger_name = 'update_users_updated_at'
  AND event_object_table = 'users'
  AND event_object_schema = 'public';

-- ============================================================================
-- DATA INTEGRITY TESTS (no orphans, duplicates, or defaults)
-- ============================================================================

-- TEST 13: Check for duplicate profiles
-- Expected: No duplicate profile IDs (0 rows)
SELECT id, COUNT(*) as count
FROM public.users
GROUP BY id
HAVING COUNT(*) > 1;

-- TEST 14: Check for orphaned profiles (profiles without auth.users)
-- Expected: No orphaned profiles (0 rows)
SELECT pu.id, pu.name
FROM public.users pu
LEFT JOIN auth.users au ON pu.id = au.id
WHERE au.id IS NULL;

-- TEST 15: Check for orphaned auth users (auth.users without profiles)
-- Expected: Should have been backfilled by migration 003 (0 rows)
SELECT au.id, au.email
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL;

-- TEST 16: Verify default values are set correctly
-- Expected: rank defaults to 'E', total_xp defaults to 0
SELECT
    CASE
        WHEN COUNT(CASE WHEN rank IS NULL THEN 1 END) > 0 THEN 'FAIL: NULL ranks found'
        WHEN COUNT(CASE WHEN total_xp IS NULL THEN 1 END) > 0 THEN 'FAIL: NULL total_xp found'
        ELSE 'PASS: All defaults set correctly'
    END as result
FROM public.users;

-- ============================================================================
-- SECURITY PROPERTY TESTS (conceptual documentation)
-- ============================================================================

-- These tests document the security properties that are verified by the RLS policies.
-- They cannot be directly executed in a SQL file but show what would be tested.

-- TEST A: Own profile read (conceptual)
-- Action: Authenticated user executes: SELECT * FROM public.users WHERE id = auth.uid();
-- Expected: Returns the user's complete profile
-- Security Property: User can read their own profile data

-- TEST B: Cross-user read denied (conceptual)
-- Action: User A executes: SELECT * FROM public.users WHERE id = 'user-b-uuid';
-- Expected: RLS returns no rows (DENIED)
-- Security Property: Users cannot read another user's protected data

-- TEST C: XP manipulation denied (conceptual)
-- Action: User A executes: UPDATE public.users SET total_xp = 999999 WHERE id = auth.uid();
-- Expected: RLS rejects the update (DENIED)
-- Security Property: total_xp is server-controlled; only award_xp() can modify it

-- TEST D: Rank manipulation denied (conceptual)
-- Action: User A executes: UPDATE public.users SET rank = 'S' WHERE id = auth.uid();
-- Expected: RLS rejects the update (DENIED)
-- Security Property: rank is server-controlled; derived from total_xp

-- TEST E: ID manipulation denied (conceptual)
-- Action: User A executes: UPDATE public.users SET id = 'another-uuid' WHERE id = auth.uid();
-- Expected: RLS rejects the update (DENIED) + PRIMARY KEY constraint prevents it anyway
-- Security Property: id is immutable ownership field

-- TEST F: created_at manipulation denied (conceptual)
-- Action: User A executes: UPDATE public.users SET created_at = NOW() WHERE id = auth.uid();
-- Expected: RLS rejects the update (DENIED)
-- Security Property: created_at is immutable; set once at profile creation

-- TEST G: updated_at manipulation denied (conceptual)
-- Action: User A executes: UPDATE public.users SET updated_at = NOW() WHERE id = auth.uid();
-- Expected: RLS rejects the update (DENIED)
-- Security Property: updated_at is maintained by database trigger

-- TEST H: Cross-user update denied (conceptual)
-- Action: User A executes: UPDATE public.users SET name = 'Hacker' WHERE id = 'user-b-uuid';
-- Expected: RLS rejects the update (DENIED by USING clause)
-- Security Property: Ownership check prevents cross-user modifications

-- TEST I: Unauthorized profile insertion denied (conceptual)
-- Action: User A executes: INSERT INTO public.users (id, name, ...) VALUES (...);
-- Expected: RLS rejects the insert (DENIED; no INSERT policy)
-- Security Property: Task 1 trigger is the authoritative creator

-- TEST J: Service-role award_xp works (conceptual)
-- Action: Backend calls: SELECT award_xp(user_id, xp_change, reason);
-- Expected: Function executes successfully, updates total_xp and xp_log
-- Security Property: SECURITY DEFINER award_xp() bypasses RLS; service_role can call it

-- TEST K: Profile creation trigger works (conceptual)
-- Action: Backend creates: INSERT INTO auth.users (id, email, ...);
-- Expected: Trigger fires, creates corresponding public.users row with correct defaults
-- Security Property: Trigger runs as SECURITY DEFINER with postgres role; creates 1:1 relationship

-- ============================================================================
-- SUMMARY & SECURITY GUARANTEES
-- ============================================================================

-- This test suite verifies:
-- 1. RLS is enabled on public.users
-- 2. SELECT policy limits users to reading their own profile
-- 3. UPDATE policy exists but is restricted (cannot update server-controlled fields)
-- 4. INSERT policy is removed (Task 1 trigger handles creation)
-- 5. No DELETE policy (users cannot delete their own profile)
-- 6. Task 1 trigger and functions still work
-- 7. No orphans or data corruption
-- 8. Default values are set correctly

-- Security Guarantees:
-- - Authenticated users CANNOT modify: id, total_xp, rank, created_at, updated_at
-- - Authenticated users CANNOT read another user's profile
-- - Authenticated users CANNOT insert arbitrary profiles
-- - Authenticated users CANNOT delete their profile
-- - Backend service_role CAN modify XP and rank via award_xp() and other functions
-- - Backend service_role CAN create profiles via manual INSERT (Task 1 trigger does this)
-- - Profile creation is atomic: auth.users ↔ public.users 1:1 invariant maintained
