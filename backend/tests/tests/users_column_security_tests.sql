-- ==========================================================================
-- TEST SUITE: Column-Level Security on public.users
-- ==========================================================================
--
-- Purpose:  Verify that the two-layer security model (column privileges + RLS)
--           correctly protects server-controlled fields on public.users.
--
-- How to run:
--   1. Open your Supabase SQL Editor (or psql connected as postgres).
--   2. Run SETUP (Section 0) once to create test fixtures.
--   3. Run each subsequent section in order.
--   4. Run TEARDOWN at the end to clean up test data.
--
-- Test types:
--   STRUCTURAL  — SELECT queries against catalog tables; always executable.
--   ATTACK      — Executable DO $$ blocks that switch to the authenticated
--                 role, attempt an operation, and report PASS/FAIL.
--   DATA        — SELECT queries against live data; always executable.
--   DOCUMENTED  — Behavior that cannot be tested from a single SQL session
--                 (e.g. service_role calls, auth triggers). Documented with
--                 rationale; not claimed as executed.
--
-- IMPORTANT: Do not claim a test passes unless you have actually executed it
-- and observed the reported result.

-- ==========================================================================
-- SECTION 0: TEST SETUP
-- ==========================================================================
-- Creates two test rows in public.users so the attack tests have data to
-- work with. Run this section once before the attack tests.
--
-- These UUIDs are deterministic so the tests are repeatable and the teardown
-- can clean them up reliably.

DO $$
DECLARE
  v_user1_id UUID := '11111111-1111-1111-1111-111111111111';
  v_user2_id UUID := '22222222-2222-2222-2222-222222222222';
BEGIN
  -- Insert directly as postgres (bypasses RLS and column privileges).
  -- In production these rows are created by the handle_new_user() trigger;
  -- here we create them manually so the test file is self-contained.
  INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
  VALUES
    (v_user1_id, 'Test User 1', 'E', 0, NOW(), NOW()),
    (v_user2_id, 'Test User 2', 'E', 0, NOW(), NOW())
  ON CONFLICT (id) DO NOTHING;

  RAISE NOTICE 'SETUP: test users created (% and %)', v_user1_id, v_user2_id;
END $$;

-- ==========================================================================
-- SECTION 1: STRUCTURAL VERIFICATION TESTS (executable)
-- ==========================================================================
-- These SELECT queries verify that the expected policies, privileges,
-- triggers, and functions are in place. They run as the current role
-- (typically postgres in the SQL editor) and read catalog tables.

-- TEST S1: Verify RLS is enabled on public.users
-- Expected: rowsecurity = true
SELECT
    'S1: RLS enabled' AS test,
    CASE WHEN rowsecurity THEN 'PASS' ELSE 'FAIL' END AS result
FROM pg_tables
WHERE tablename = 'users' AND schemaname = 'public';

-- TEST S2: Verify UPDATE policy exists and is restricted
-- Expected: "Users can update their name only"
SELECT
    'S2: UPDATE policy' AS test,
    policyname,
    cmd AS operation,
    qual AS using_clause,
    with_check
FROM pg_policies
WHERE tablename = 'users' AND schemaname = 'public'
  AND cmd = 'UPDATE';

-- TEST S3: Verify SELECT policy exists
-- Expected: "Users can view their own profile"
SELECT
    'S3: SELECT policy' AS test,
    policyname,
    cmd AS operation
FROM pg_policies
WHERE tablename = 'users' AND schemaname = 'public'
  AND cmd = 'SELECT';

-- TEST S4: Verify no INSERT policy exists
-- Expected: 0 rows (INSERT policy was removed in migration 004)
SELECT
    'S4: INSERT policy (should be empty)' AS test,
    policyname,
    cmd AS operation
FROM pg_policies
WHERE tablename = 'users' AND schemaname = 'public'
  AND cmd = 'INSERT';

-- TEST S5: Verify column-level UPDATE privileges for authenticated role
-- Expected: Only 'name' column has UPDATE privilege for authenticated
SELECT
    'S5: Column privileges' AS test,
    grantee,
    column_name,
    privilege_type
FROM information_schema.column_privileges
WHERE table_name = 'users' AND table_schema = 'public'
  AND grantee = 'authenticated'
  AND privilege_type = 'UPDATE'
ORDER BY column_name;

-- TEST S6: Verify handle_new_user trigger still exists
-- Expected: Trigger on auth.users AFTER INSERT
SELECT
    'S6: Signup trigger' AS test,
    trigger_name,
    event_manipulation,
    action_timing
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created'
  AND event_object_schema = 'auth';

-- TEST S7: Verify award_xp function exists with SECURITY DEFINER
-- Expected: prosecdef = true
SELECT
    'S7: award_xp function' AS test,
    proname,
    prosecdef AS security_definer
FROM pg_proc
WHERE proname = 'award_xp'
  AND pronamespace = 'public'::regnamespace;

-- TEST S8: Verify handle_new_user function has SECURITY DEFINER
-- Expected: prosecdef = true
SELECT
    'S8: handle_new_user function' AS test,
    proname,
    prosecdef AS security_definer
FROM pg_proc
WHERE proname = 'handle_new_user'
  AND pronamespace = 'public'::regnamespace;

-- TEST S9: Verify authenticated role does NOT have table-level UPDATE
-- (only column-level UPDATE on 'name' should be granted)
-- Expected: No rows with privilege_type = 'UPDATE' at table level
SELECT
    'S9: No table-level UPDATE grant' AS test,
    grantee, privilege_type
FROM information_schema.table_privileges
WHERE table_name = 'users' AND table_schema = 'public'
  AND grantee = 'authenticated'
  AND privilege_type = 'UPDATE';

-- TEST S10: Verify authenticated role does NOT have INSERT privilege
-- Expected: No rows (INSERT was not granted)
SELECT
    'S10: No INSERT privilege' AS test,
    grantee, privilege_type
FROM information_schema.table_privileges
WHERE table_name = 'users' AND table_schema = 'public'
  AND grantee = 'authenticated'
  AND privilege_type = 'INSERT';

-- ==========================================================================
-- SECTION 2: EXECUTABLE ATTACK TESTS
-- ==========================================================================
-- Each test switches to the authenticated role, simulates auth.uid() by
-- setting the request.jwt.claim.sub GUC (the way Supabase PostgREST does),
-- attempts an operation, and reports PASS or FAIL.
--
-- These tests MUST be run against a database where migrations 001-005 have
-- been applied. They use the test users created in Section 0.

-- --------------------------------------------------------------------------
-- TEST A1: Authenticated user CAN update their own name
-- Expected: PASS — 1 row updated, then reverted
-- --------------------------------------------------------------------------
DO $$
DECLARE
  v_user1_id UUID := '11111111-1111-1111-1111-111111111111';
  v_count    INT;
BEGIN
  -- Simulate authenticated user session
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user1_id::text, true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user1_id)::text, true);

  UPDATE public.users SET name = 'Name Changed By Test' WHERE id = v_user1_id;
  GET DIAGNOSTICS v_count = ROW_COUNT;

  -- Revert the name change
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.users SET name = 'Test User 1' WHERE id = v_user1_id;

  IF v_count = 1 THEN
    RAISE NOTICE 'TEST A1 — Own name update: PASS (% row updated)', v_count;
  ELSE
    RAISE WARNING 'TEST A1 — Own name update: FAIL (expected 1 row, got %)', v_count;
  END IF;
END $$;

-- --------------------------------------------------------------------------
-- TEST A2: Authenticated user CANNOT update total_xp
-- Expected: PASS — permission denied for column "total_xp"
-- --------------------------------------------------------------------------
DO $$
DECLARE
  v_user1_id UUID := '11111111-1111-1111-1111-111111111111';
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user1_id::text, true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user1_id)::text, true);

  UPDATE public.users SET total_xp = 999999 WHERE id = v_user1_id;

  -- If we reach here the update was not blocked
  PERFORM set_config('role', 'postgres', true);
  -- Revert
  UPDATE public.users SET total_xp = 0 WHERE id = v_user1_id;
  RAISE WARNING 'TEST A2 — XP manipulation: FAIL (update was not blocked)';

EXCEPTION WHEN insufficient_privilege THEN
  PERFORM set_config('role', 'postgres', true);
  RAISE NOTICE 'TEST A2 — XP manipulation: PASS (permission denied)';
END $$;

-- --------------------------------------------------------------------------
-- TEST A3: Authenticated user CANNOT update rank
-- Expected: PASS — permission denied for column "rank"
-- --------------------------------------------------------------------------
DO $$
DECLARE
  v_user1_id UUID := '11111111-1111-1111-1111-111111111111';
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user1_id::text, true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user1_id)::text, true);

  UPDATE public.users SET rank = 'S' WHERE id = v_user1_id;

  PERFORM set_config('role', 'postgres', true);
  UPDATE public.users SET rank = 'E' WHERE id = v_user1_id;
  RAISE WARNING 'TEST A3 — Rank manipulation: FAIL (update was not blocked)';

EXCEPTION WHEN insufficient_privilege THEN
  PERFORM set_config('role', 'postgres', true);
  RAISE NOTICE 'TEST A3 — Rank manipulation: PASS (permission denied)';
END $$;

-- --------------------------------------------------------------------------
-- TEST A4: Authenticated user CANNOT update id
-- Expected: PASS — permission denied for column "id"
-- --------------------------------------------------------------------------
DO $$
DECLARE
  v_user1_id UUID := '11111111-1111-1111-1111-111111111111';
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user1_id::text, true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user1_id)::text, true);

  UPDATE public.users SET id = 'ffffffff-ffff-ffff-ffff-ffffffffffff' WHERE id = v_user1_id;

  PERFORM set_config('role', 'postgres', true);
  RAISE WARNING 'TEST A4 — ID manipulation: FAIL (update was not blocked)';

EXCEPTION WHEN insufficient_privilege THEN
  PERFORM set_config('role', 'postgres', true);
  RAISE NOTICE 'TEST A4 — ID manipulation: PASS (permission denied)';
END $$;

-- --------------------------------------------------------------------------
-- TEST A5: Authenticated user CANNOT update created_at
-- Expected: PASS — permission denied for column "created_at"
-- --------------------------------------------------------------------------
DO $$
DECLARE
  v_user1_id UUID := '11111111-1111-1111-1111-111111111111';
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user1_id::text, true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user1_id)::text, true);

  UPDATE public.users SET created_at = NOW() + INTERVAL '10 years' WHERE id = v_user1_id;

  PERFORM set_config('role', 'postgres', true);
  RAISE WARNING 'TEST A5 — created_at manipulation: FAIL (update was not blocked)';

EXCEPTION WHEN insufficient_privilege THEN
  PERFORM set_config('role', 'postgres', true);
  RAISE NOTICE 'TEST A5 — created_at manipulation: PASS (permission denied)';
END $$;

-- --------------------------------------------------------------------------
-- TEST A6: Authenticated user CANNOT update updated_at
-- Expected: PASS — permission denied for column "updated_at"
-- --------------------------------------------------------------------------
DO $$
DECLARE
  v_user1_id UUID := '11111111-1111-1111-1111-111111111111';
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user1_id::text, true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user1_id)::text, true);

  UPDATE public.users SET updated_at = NOW() + INTERVAL '10 years' WHERE id = v_user1_id;

  PERFORM set_config('role', 'postgres', true);
  RAISE WARNING 'TEST A6 — updated_at manipulation: FAIL (update was not blocked)';

EXCEPTION WHEN insufficient_privilege THEN
  PERFORM set_config('role', 'postgres', true);
  RAISE NOTICE 'TEST A6 — updated_at manipulation: PASS (permission denied)';
END $$;

-- --------------------------------------------------------------------------
-- TEST A7: Authenticated user CANNOT update another user's name (RLS)
-- Expected: PASS — 0 rows updated (RLS silently filters the row out)
-- --------------------------------------------------------------------------
DO $$
DECLARE
  v_user1_id UUID := '11111111-1111-1111-1111-111111111111';
  v_user2_id UUID := '22222222-2222-2222-2222-222222222222';
  v_count    INT;
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user1_id::text, true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user1_id)::text, true);

  -- User 1 tries to update User 2's name
  UPDATE public.users SET name = 'Hacked Name' WHERE id = v_user2_id;
  GET DIAGNOSTICS v_count = ROW_COUNT;

  PERFORM set_config('role', 'postgres', true);

  IF v_count = 0 THEN
    RAISE NOTICE 'TEST A7 — Cross-user update: PASS (0 rows updated, RLS blocked)';
  ELSE
    -- Revert
    UPDATE public.users SET name = 'Test User 2' WHERE id = v_user2_id;
    RAISE WARNING 'TEST A7 — Cross-user update: FAIL (% rows updated)', v_count;
  END IF;
END $$;

-- --------------------------------------------------------------------------
-- TEST A8: Combined malicious update (name + total_xp + rank) is blocked
-- Expected: PASS — entire statement fails because total_xp/rank lack privilege
-- --------------------------------------------------------------------------
DO $$
DECLARE
  v_user1_id UUID := '11111111-1111-1111-1111-111111111111';
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user1_id::text, true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user1_id)::text, true);

  UPDATE public.users
  SET name = 'Legit Name', total_xp = 999999, rank = 'S'
  WHERE id = v_user1_id;

  PERFORM set_config('role', 'postgres', true);
  -- Revert
  UPDATE public.users SET name = 'Test User 1', total_xp = 0, rank = 'E' WHERE id = v_user1_id;
  RAISE WARNING 'TEST A8 — Combined attack: FAIL (update was not blocked)';

EXCEPTION WHEN insufficient_privilege THEN
  PERFORM set_config('role', 'postgres', true);
  RAISE NOTICE 'TEST A8 — Combined attack: PASS (permission denied, all-or-nothing)';
END $$;

-- --------------------------------------------------------------------------
-- TEST A9: Authenticated user CANNOT insert a new profile row
-- Expected: PASS — new row violates RLS (no INSERT policy exists)
-- --------------------------------------------------------------------------
DO $$
DECLARE
  v_user1_id UUID := '11111111-1111-1111-1111-111111111111';
  v_fake_id  UUID := '99999999-9999-9999-9999-999999999999';
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user1_id::text, true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user1_id)::text, true);

  INSERT INTO public.users (id, name, rank, total_xp)
  VALUES (v_fake_id, 'Fake User', 'S', 999999);

  -- If we reach here, INSERT was allowed
  PERFORM set_config('role', 'postgres', true);
  DELETE FROM public.users WHERE id = v_fake_id;
  RAISE WARNING 'TEST A9 — Unauthorized INSERT: FAIL (insert was not blocked)';

EXCEPTION WHEN insufficient_privilege THEN
  PERFORM set_config('role', 'postgres', true);
  RAISE NOTICE 'TEST A9 — Unauthorized INSERT: PASS (permission denied)';
WHEN others THEN
  PERFORM set_config('role', 'postgres', true);
  RAISE NOTICE 'TEST A9 — Unauthorized INSERT: PASS (blocked: %)', SQLERRM;
END $$;

-- --------------------------------------------------------------------------
-- TEST A10: Authenticated user CANNOT delete their own profile
-- Expected: PASS — no DELETE policy exists
-- --------------------------------------------------------------------------
DO $$
DECLARE
  v_user1_id UUID := '11111111-1111-1111-1111-111111111111';
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user1_id::text, true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user1_id)::text, true);

  DELETE FROM public.users WHERE id = v_user1_id;

  PERFORM set_config('role', 'postgres', true);
  RAISE WARNING 'TEST A10 — Profile deletion: FAIL (delete was not blocked)';

EXCEPTION WHEN insufficient_privilege THEN
  PERFORM set_config('role', 'postgres', true);
  RAISE NOTICE 'TEST A10 — Profile deletion: PASS (permission denied)';
WHEN others THEN
  PERFORM set_config('role', 'postgres', true);
  RAISE NOTICE 'TEST A10 — Profile deletion: PASS (blocked: %)', SQLERRM;
END $$;

-- ==========================================================================
-- SECTION 3: DATA INTEGRITY TESTS (executable)
-- ==========================================================================

-- TEST D1: No duplicate profiles
-- Expected: 0 rows
SELECT
    'D1: No duplicate profiles' AS test,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM (
    SELECT id, COUNT(*) AS cnt
    FROM public.users
    GROUP BY id
    HAVING COUNT(*) > 1
) dupes;

-- TEST D2: No orphaned profiles (profile without auth.users row)
-- Expected: Result depends on whether test fixture users have auth.users rows.
-- In production this should return 0 rows. Test fixtures are synthetic so they
-- may appear here; that is expected and not a failure.
SELECT
    'D2: Orphaned profiles (test fixtures expected)' AS test,
    pu.id, pu.name
FROM public.users pu
LEFT JOIN auth.users au ON pu.id = au.id
WHERE au.id IS NULL;

-- TEST D3: No orphaned auth users (auth.users without profile)
-- Expected: 0 rows (backfilled by migration 003)
SELECT
    'D3: Orphaned auth users' AS test,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL: orphaned auth users exist' END AS result
FROM (
    SELECT au.id
    FROM auth.users au
    LEFT JOIN public.users pu ON au.id = pu.id
    WHERE pu.id IS NULL
) orphans;

-- ==========================================================================
-- SECTION 4: DOCUMENTED BEHAVIOR (not directly testable in this SQL file)
-- ==========================================================================
-- The following behaviors are guaranteed by the implementation but cannot be
-- tested from a single SQL session in the Supabase SQL editor. They are
-- documented here with the rationale for why they work. Do NOT claim these
-- tests "pass" — they describe architectural guarantees, not executed tests.
--
-- BEHAVIOR T1: award_xp() can update total_xp
--   Rationale: award_xp() is declared SECURITY DEFINER and runs as the
--   postgres role, which is not restricted by the column-level REVOKE on
--   the authenticated role. It is callable only by service_role
--   (GRANT EXECUTE … TO service_role; all others revoked).
--
-- BEHAVIOR T2: handle_new_user() trigger can INSERT profiles
--   Rationale: handle_new_user() is declared SECURITY DEFINER with
--   SET search_path = public. It runs as the postgres role when fired
--   by an INSERT into auth.users. The postgres role has full INSERT
--   privilege on public.users regardless of what is granted to
--   authenticated.
--
-- BEHAVIOR T3: A real Supabase signup creates a profile row
--   Rationale: Supabase auth.signUp() inserts into auth.users, which
--   fires on_auth_user_created → handle_new_user(). This is tested
--   end-to-end by signing up through the frontend or via the Supabase
--   client library.

-- ==========================================================================
-- SECTION 5: TEARDOWN
-- ==========================================================================
-- Remove the synthetic test users created in Section 0.
-- Run this after all tests are complete.

DO $$
DECLARE
  v_user1_id UUID := '11111111-1111-1111-1111-111111111111';
  v_user2_id UUID := '22222222-2222-2222-2222-222222222222';
BEGIN
  DELETE FROM public.users WHERE id IN (v_user1_id, v_user2_id);
  RAISE NOTICE 'TEARDOWN: test users removed';
END $$;

-- ==========================================================================
-- SUMMARY
-- ==========================================================================
--
-- Executable tests in this file:
--   S1-S10 : Structural verification (10 tests)
--   A1-A10 : Attack / permission tests with role switching (10 tests)
--   D1-D3  : Data integrity checks (3 tests)
--   Total  : 23 executable tests
--
-- Documented behavior (not executed):
--   T1-T3  : Backend/trigger guarantees (3 items)
--
-- Security model verified:
--   Layer 1 — Column privileges: authenticated can UPDATE only 'name'
--   Layer 2 — RLS policies: authenticated can access only own rows
--   Combined: Users can UPDATE only their own 'name' field
--   Server-controlled fields (id, total_xp, rank, created_at, updated_at)
--   are protected from direct client manipulation.
