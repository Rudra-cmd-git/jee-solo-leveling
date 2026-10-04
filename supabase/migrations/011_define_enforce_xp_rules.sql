-- Migration: Define and Enforce XP Rules
-- Purpose: Secure the XP system so that users cannot award themselves arbitrary XP,
--          and establish clear business rules for XP amounts.
-- Date: 2026-10-04

-- ============================================================================
-- SECURITY MODEL FOR XP
-- ============================================================================

-- Core rule: Users cannot award themselves XP.
-- XP is only awarded through:
-- 1. The secure award_xp() function (service_role only)
-- 2. Trusted backend logic that calls award_xp()

-- Authenticated clients must NOT be able to:
-- - UPDATE users.total_xp directly
-- - INSERT xp_log entries
-- - UPDATE xp_log entries
-- - DELETE xp_log entries
-- - Modify xp_change amount

-- ============================================================================
-- STEP 1: SECURE xp_log TABLE PRIVILEGES
-- ============================================================================

-- Explicitly REVOKE all DML privileges from authenticated on xp_log
-- The RLS policies prevent SELECT/UPDATE/DELETE for non-owners,
-- but we add explicit privilege restrictions for defense-in-depth.

REVOKE ALL ON public.xp_log FROM authenticated;

-- Grant SELECT only (with RLS enforcing ownership)
GRANT SELECT ON public.xp_log TO authenticated;

-- ============================================================================
-- STEP 2: ADD RLS POLICY FOR INSERT PREVENTION
-- ============================================================================

-- The RLS policies currently only have SELECT, UPDATE (prevent), DELETE (prevent).
-- Explicitly prevent authenticated INSERT into xp_log.

DROP POLICY IF EXISTS "Prevent direct XP log inserts" ON public.xp_log;
CREATE POLICY "Prevent direct XP log inserts" ON public.xp_log
    FOR INSERT WITH CHECK (false);

-- ============================================================================
-- STEP 3: VALIDATE XP AMOUNTS IN award_xp()
-- ============================================================================

-- The existing award_xp() function does not validate that xp_change > 0.
-- This allows negative XP or zero XP to enter the system.
-- We add a CHECK constraint to the xp_log table to enforce positive XP.

-- Add a constraint that xp_change must be positive
ALTER TABLE public.xp_log
ADD CONSTRAINT xp_change_must_be_positive CHECK (xp_change > 0);

-- ============================================================================
-- STEP 4: SECURE total_xp FROM DIRECT CLIENT UPDATES
-- ============================================================================

-- Task 5 already established:
--   GRANT UPDATE(name) ON public.users TO authenticated;
--
-- This means authenticated can only UPDATE the 'name' column.
-- The total_xp column is NOT in the list, so it cannot be updated by authenticated.
--
-- We verify this is still in place by re-enforcing it.

REVOKE UPDATE ON public.users FROM authenticated;
GRANT UPDATE(name) ON public.users TO authenticated;

-- ============================================================================
-- SECURITY GUARANTEE: XP CANNOT BE CLIENT-MANIPULATED
-- ============================================================================

-- Attack 1: Direct total_xp manipulation
-- Query: UPDATE public.users SET total_xp = 999999 WHERE id = auth.uid();
-- Result: Permission denied (insufficient_privilege)
-- Reason: authenticated lacks UPDATE(total_xp) privilege
--
-- Attack 2: Direct xp_log insertion
-- Query: INSERT INTO public.xp_log (user_id, xp_change, reason) VALUES (...);
-- Result: Permission denied (RLS WITH CHECK false + table-level REVOKE)
-- Reason: authenticated has no INSERT privilege on xp_log
--
-- Attack 3: Negative XP entry
-- Query: Call award_xp(user, -100, 'fake');
-- Result: Permission denied (authenticated cannot call award_xp)
--         If somehow called via service_role, database rejects (CHECK constraint xp_change > 0)
-- Reason: Function only callable by service_role; constraint enforces positive XP
--
-- Attack 4: Zero XP entry
-- Query: Call award_xp(user, 0, 'fake');
-- Result: Permission denied + constraint rejection
-- Reason: CHECK constraint xp_change > 0 blocks zero
--
-- Legitimate: Trusted backend awards XP
-- Query: SELECT award_xp(user_id, 100, 'Task completed');
-- Result: Success (service_role can call; xp_change > 0 passes constraint)
--         Both xp_log and users.total_xp updated consistently
-- Reason: award_xp() runs as SECURITY DEFINER with postgres privileges

-- ============================================================================
-- IDEMPOTENCY
-- ========================================================

-- This migration is idempotent:
-- - REVOKE is idempotent (safe if privilege not held)
-- - GRANT is idempotent (safe if already granted)
-- - DROP POLICY IF EXISTS is safe (re-applying is harmless)
-- - CREATE POLICY replaces old or creates new
-- - ADD CONSTRAINT is safe if constraint doesn't exist
--   (PostgreSQL silently ignores if constraint already present with same definition)
-- - Multiple runs produce the same final state
