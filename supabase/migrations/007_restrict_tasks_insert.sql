-- Migration: Restrict public.tasks INSERT privilege
-- Purpose: Revoke direct INSERT privilege from authenticated role, enforcing server-side task creation.
-- Date: 2026-10-04

-- 1. Revoke INSERT privilege from authenticated role
REVOKE INSERT ON public.tasks FROM authenticated;

-- 2. Drop the insert policy (no longer relevant if INSERT is revoked, but cleaner to remove)
DROP POLICY IF EXISTS "Users can insert their own tasks" ON public.tasks;
