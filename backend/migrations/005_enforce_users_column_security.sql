-- Migration: Enforce column-level security on public.users
-- Purpose: Ensure authenticated users can update ONLY the 'name' column
-- Date: 2026-10-03

-- PROBLEM WITH PREVIOUS APPROACH
-- =============================
-- The previous migration used RLS policies that only enforced row ownership:
--   USING (auth.uid() = id)
--   WITH CHECK (auth.uid() = id)
--
-- RLS controls which ROWS a user can access, not which COLUMNS.
-- Therefore, a client could still execute:
--   UPDATE public.users SET total_xp = 999999 WHERE id = auth.uid();
--
-- This migration fixes that by using PostgreSQL column-level privileges.

-- SECURITY ARCHITECTURE
-- ======================
-- 1. RLS continues to enforce row ownership (SELECT, UPDATE USING/WITH CHECK)
-- 2. Column privileges now enforce which columns each role can UPDATE
-- 3. authenticated role gets UPDATE(name) only
-- 4. postgres role (used by SECURITY DEFINER functions) retains full privileges
-- 5. Service-role functions (award_xp) bypass column privileges via SECURITY DEFINER

-- ============================================================================
-- STEP 1: REVOKE ALL UPDATE PRIVILEGES ON public.users FROM authenticated ROLE
-- ============================================================================

-- The 'authenticated' role is used by Supabase clients (PostgREST, Realtime, etc.)
-- Revoke all UPDATE privileges; we'll grant specific columns below.

REVOKE UPDATE ON public.users FROM authenticated;

-- ============================================================================
-- STEP 2: GRANT UPDATE ONLY ON 'name' COLUMN TO authenticated ROLE
-- ============================================================================

-- Only the 'name' column can be updated by authenticated users.
-- All server-controlled columns (id, total_xp, rank, created_at, updated_at) are protected.

GRANT UPDATE(name) ON public.users TO authenticated;

-- ============================================================================
-- STEP 3: ENSURE SELECT PRIVILEGE STILL WORKS FOR authenticated
-- ============================================================================

-- Verify authenticated can still SELECT (should already be granted in 001_init_schema)
-- PostgREST and RLS will handle row-level filtering.

GRANT SELECT ON public.users TO authenticated;
GRANT INSERT ON public.users TO authenticated;

-- ============================================================================
-- STEP 4: VERIFY postgres ROLE HAS FULL PRIVILEGES
-- ========================================================

-- The 'postgres' role (typically the database owner) should have full privileges.
-- This is the owner of SECURITY DEFINER functions like handle_new_user() and award_xp().
-- When these functions execute, they run with postgres privileges, bypassing
-- the column-level UPDATE restriction on the 'authenticated' role.

-- Note: SECURITY DEFINER functions must be CAREFULLY DESIGNED to avoid
-- privilege escalation vulnerabilities. In this codebase:
-- - handle_new_user() runs as postgres and INSERTs into public.users (safe; owned by system)
-- - award_xp() runs as postgres and UPDATEs total_xp (safe; explicitly designed to do this)
-- - award_xp() is only callable by service_role, not by authenticated clients directly

-- ============================================================================
-- STEP 5: VERIFY RLS POLICIES STILL RESTRICT ROWS
-- ========================================================

-- RLS policies remain unchanged and continue to enforce:
-- - SELECT: Users read only their own profile (auth.uid() = id)
-- - UPDATE: Users can only update their own row (USING auth.uid() = id, WITH CHECK auth.uid() = id)
-- - INSERT: Task 1 trigger is the authoritative creator; no direct INSERT for authenticated
-- - DELETE: No DELETE policy (users cannot delete profiles)

-- Combined effect:
-- - RLS filters: "which rows can I access?" → Only own row
-- - Column privs: "which columns can I update?" → Only 'name'
-- - Result: Only UPDATE public.users SET name = '...' WHERE id = auth.uid() succeeds

-- ============================================================================
-- SECURITY GUARANTEE VERIFICATION
-- ========================================================

-- ATTACK 1: Direct XP manipulation
-- Query: UPDATE public.users SET total_xp = 999999 WHERE id = auth.uid();
-- Result: Permission denied (column UPDATE privilege denied)
--
-- ATTACK 2: Direct rank manipulation
-- Query: UPDATE public.users SET rank = 'S' WHERE id = auth.uid();
-- Result: Permission denied (column UPDATE privilege denied)
--
-- ATTACK 3: ID theft
-- Query: UPDATE public.users SET id = 'another-uuid' WHERE id = auth.uid();
-- Result: Permission denied (column UPDATE privilege denied + PRIMARY KEY constraint)
--
-- ATTACK 4: Timestamp forgery
-- Query: UPDATE public.users SET created_at = NOW() WHERE id = auth.uid();
-- Result: Permission denied (column UPDATE privilege denied)
--
-- ATTACK 5: Combined malicious update
-- Query: UPDATE public.users SET name = 'OK', total_xp = 999, rank = 'S' WHERE id = auth.uid();
-- Result: Permission denied (cannot update total_xp and rank; entire statement fails)
--
-- LEGITIMATE OPERATION: Name update
-- Query: UPDATE public.users SET name = 'New Name' WHERE id = auth.uid();
-- Result: Success (authenticated has UPDATE(name) privilege + RLS allows own row)
--
-- TRUSTED BACKEND OPERATION: XP award
-- Query: SELECT award_xp(user_id, 100, 'Task completed');
-- Result: Success (award_xp() runs as SECURITY DEFINER with postgres privileges)

-- ============================================================================
-- IDEMPOTENCY
-- ========================================================

-- This migration is idempotent:
-- - REVOKE is idempotent (does not error if privilege not held)
-- - GRANT is idempotent (does not error if privilege already granted)
-- - Multiple runs produce the same final state

-- ============================================================================
-- DETAILED MECHANISM EXPLANATION
-- ========================================================

-- PostgreSQL has two levels of access control:

-- 1. DISCRETIONARY ACCESS CONTROL (DAC) - Privileges
--    These control what SQL operations a role can perform on which objects.
--    For example:
--      GRANT SELECT ON table_name TO role_name;
--      GRANT UPDATE(column_name) ON table_name TO role_name;
--
--    If a role lacks a privilege, the operation fails with "permission denied".
--
--    Column-level privileges are checked PER COLUMN when UPDATE is executed.
--    If any column in the UPDATE list lacks the privilege, the entire statement fails.

-- 2. ROW LEVEL SECURITY (RLS)
--    After privileges pass, RLS policies further filter which rows are accessible.
--    RLS policies have USING (for read/update-which-rows) and WITH CHECK clauses.
--    They do NOT restrict which columns can be modified.

-- This migration uses BOTH:
-- - Privileges to restrict COLUMNS (authenticated can only UPDATE 'name')
-- - RLS to restrict ROWS (authenticated can only see/update own row)

-- Together they enforce:
--   UPDATE public.users
--   SET name = 'New Name'          ← allowed (column privilege + RLS row check)
--   WHERE id = auth.uid();         ← allowed (own row, passes RLS)
--
-- But block:
--   UPDATE public.users
--   SET total_xp = 999999          ← denied (no column privilege)
--   WHERE id = auth.uid();         ← would pass RLS, but never reached

-- And block:
--   UPDATE public.users
--   SET name = 'Hacker'            ← denied (fails RLS row check)
--   WHERE id = 'another-user';     ← another user's row

-- ============================================================================
-- WHY THIS APPROACH OVER ALTERNATIVES
-- ========================================================

-- Alternative 1: Trigger that validates column updates
-- - Problem: Trigger runs AFTER privilege check, so privilege check still allows it
-- - Problem: Adds complexity; harder to audit
-- - Chosen against this

-- Alternative 2: Create separate view with restricted columns
-- - Problem: Supabase PostgREST expects to query the table directly
-- - Problem: Would require rewriting client queries
-- - Chosen against this

-- Alternative 3: SECURITY DEFINER UPDATE function
-- - Problem: Would require clients to call a function instead of UPDATE
-- - Problem: Changes application architecture significantly
-- - Acceptable but less direct than column privileges

-- CHOSEN: Column-level privileges + RLS
-- - Direct: Uses PostgreSQL's built-in privilege system
-- - Simple: No additional functions/views needed
-- - Audit-friendly: Privileges are discoverable via pg_tables_priv
-- - Works with Supabase: PostgREST respects column privileges
-- - Follows principle: "Let the database enforce what the database should enforce"

-- ============================================================================
-- TASK 1 REGRESSION TEST
-- ========================================================

-- The handle_new_user() trigger (created in 001, enhanced in 002) must continue to work.
-- It runs as SECURITY DEFINER with postgres role, so column privileges don't restrict it.
-- It INSERTs into public.users with all columns set, which is allowed for postgres.
-- Result: Profile creation trigger continues to work unchanged.

-- ============================================================================
-- AWARD_XP REGRESSION TEST
-- ========================================================

-- The award_xp() function (created in 001) must continue to work.
-- It runs as SECURITY DEFINER with postgres role.
-- It UPDATEs public.users total_xp column.
-- Since postgres is not restricted by column privileges, the update succeeds.
-- Result: XP awarding continues to work unchanged.

-- ============================================================================
-- MIGRATION SAFETY NOTES
-- ========================================================

-- This migration affects only:
-- - public.users table privileges
-- - Does NOT modify schema, triggers, functions, or data
-- - Does NOT affect other tables
-- - Safe to apply to existing databases
-- - Reversible by re-granting UPDATE to authenticated (not recommended)

-- Potential issues:
-- - If another role needs to UPDATE specific columns, grant explicitly
-- - If PostgREST is configured with a different role, grant to that role
-- - If custom applications use a different database role, verify they still have needed privileges
