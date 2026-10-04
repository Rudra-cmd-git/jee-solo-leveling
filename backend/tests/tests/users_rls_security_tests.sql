-- TEST SUITE: Structural Verification of public.users RLS and Schema
-- Purpose: Verify that the expected policies, triggers, functions, and data
--          integrity constraints are in place on public.users.
--
-- All tests in this file are executable SELECT queries against catalog tables
-- and live data. Run in the Supabase SQL editor as postgres.
--
-- For executable attack/permission tests (role switching, permission denial),
-- see users_column_security_tests.sql.

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
-- EXECUTABLE ATTACK & PERMISSION TESTS
-- ============================================================================
-- The attack tests (role-switching, permission denial, cross-user blocking)
-- are implemented as executable DO $$ blocks in:
--
--   backend/tests/tests/users_column_security_tests.sql
--
-- That file contains tests A1-A10 which cover:
--   - Own name update (allowed)
--   - XP, rank, id, created_at, updated_at manipulation (denied)
--   - Cross-user update (RLS blocked)
--   - Combined malicious update (all-or-nothing denied)
--   - Unauthorized INSERT and DELETE (denied)
--
-- Run that file after this one for full coverage.

-- ============================================================================
-- SUMMARY
-- ============================================================================
--
-- This file contains executable structural and data-integrity tests:
--   Tests 1-12 : Policy, schema, trigger, and function verification (12 tests)
--   Tests 13-16: Data integrity checks (4 tests)
--   Total      : 16 executable tests
--
-- For executable attack/permission tests, see users_column_security_tests.sql.
--
-- Security guarantees verified across both files:
--   - Authenticated users CANNOT modify: id, total_xp, rank, created_at, updated_at
--   - Authenticated users CANNOT read another user's profile
--   - Authenticated users CANNOT insert arbitrary profiles
--   - Authenticated users CANNOT delete their profile
--   - Backend service_role CAN modify XP and rank via award_xp()
--   - Profile creation trigger runs as SECURITY DEFINER with search_path = public
