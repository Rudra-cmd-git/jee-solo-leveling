-- Migration: Enforce rank as server-controlled field
-- Purpose: Ensure authenticated users cannot directly INSERT or UPDATE the "rank" field
--          while preserving legitimate authenticated operations (UPDATE name, SELECT own profile)
--          and trusted backend/service-role rank management capabilities.
-- Date: 2026-10-04

-- ============================================================================
-- SECURITY MODEL FOR RANK
-- ============================================================================

-- Background:
-- - Task 1 established profile creation via trigger (handle_new_user)
-- - Task 2 added column-level UPDATE restriction to name only
-- - Task 4 completed submissions security with column-level privileges
-- - This task (Task 5) finalizes rank as server-controlled via explicit privileges

-- Current state before this migration:
-- - Migration 004 removed the "Users can insert their own profile" RLS policy
-- - Migration 005 added GRANT UPDATE(name) but left other details implicit
-- - No explicit REVOKE of INSERT privilege on public.users from authenticated

-- This migration makes rank security explicit and complete:
-- 1. Authenticated cannot INSERT into public.users at all
-- 2. Authenticated cannot UPDATE public.users.rank column
-- 3. Trusted backend/service-role retains full rank management capability

-- ============================================================================
-- STEP 1: REVOKE INSERT PRIVILEGE ON public.users FROM authenticated
-- ============================================================================

-- Explicit revocation: authenticated role cannot INSERT new users
-- Profile creation is handled exclusively by the handle_new_user() trigger
-- which runs as SECURITY DEFINER with postgres role privileges

REVOKE INSERT ON public.users FROM authenticated;

-- ============================================================================
-- STEP 2: VERIFY UPDATE(name) ONLY - NO UPDATE(rank)
-- ============================================================================

-- Migration 005 already established:
--   REVOKE UPDATE ON public.users FROM authenticated;
--   GRANT UPDATE(name) ON public.users TO authenticated;
--
-- This ensures authenticated can only update the 'name' column.
-- Server-controlled columns (id, total_xp, rank, created_at, updated_at)
-- remain protected by column-level DAC (Discretionary Access Control).

-- For absolute clarity and idempotency, we reinforce:
REVOKE UPDATE ON public.users FROM authenticated;
GRANT UPDATE(name) ON public.users TO authenticated;

-- ============================================================================
-- STEP 3: ENSURE SELECT REMAINS AVAILABLE
-- ============================================================================

-- Authenticated users must still be able to read their own profile (via RLS)
-- and to verify their rank and other public fields

GRANT SELECT ON public.users TO authenticated;

-- ============================================================================
-- STEP 4: TRUSTED BACKEND RETAINS FULL PRIVILEGE
-- ============================================================================

-- The 'postgres' role (and service_role through SECURITY DEFINER functions)
-- retains full privilege to UPDATE all columns including rank.
--
-- Example trusted operations:
-- - award_xp() function can UPDATE rank (via stored procedure)
-- - future rank_update() function can UPDATE rank (via stored procedure)
-- - Backend services running as service_role can UPDATE rank
--
-- These operations are protected by:
-- 1. Service-role authentication (backend credentials)
-- 2. SECURITY DEFINER functions that validate inputs
-- 3. No direct UPDATE allowed from authenticated clients

-- ============================================================================
-- SECURITY GUARANTEE: RANK CANNOT BE CLIENT-MANIPULATED
-- ============================================================================

-- Attack 1: Authenticated user attempts direct rank update
-- Query: UPDATE public.users SET rank = 'S' WHERE id = auth.uid();
-- Result: Permission denied (insufficient_privilege)
-- Reason: authenticated lacks UPDATE(rank) privilege
--
-- Attack 2: Authenticated user attempts to insert with rank
-- Query: INSERT INTO public.users (id, name, rank) VALUES (...);
-- Result: Permission denied (insufficient_privilege)
-- Reason: authenticated lacks INSERT privilege on public.users
--
-- Attack 3: Authenticated user attempts combined name+rank update
-- Query: UPDATE public.users SET name = 'OK', rank = 'S' WHERE id = auth.uid();
-- Result: Permission denied (insufficient_privilege)
-- Reason: rank column update is denied; entire statement fails
--
-- Legitimate: Name update still works
-- Query: UPDATE public.users SET name = 'New Name' WHERE id = auth.uid();
-- Result: Success (authenticated has UPDATE(name) + RLS allows own row)
--
-- Trusted backend: Service-role rank update (via function)
-- Query: SELECT award_xp(user_id, 100, 'Task completed');
-- Result: Success (award_xp runs as SECURITY DEFINER with postgres privileges)

-- ============================================================================
-- IDEMPOTENCY
-- ========================================================

-- This migration is idempotent:
-- - REVOKE is idempotent (safe if privilege not currently held)
-- - GRANT is idempotent (safe if privilege already granted)
-- - Multiple runs produce the same final state
-- - Safe to apply to databases with existing user data
