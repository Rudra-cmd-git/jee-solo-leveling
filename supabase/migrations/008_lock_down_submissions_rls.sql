-- Migration: Lock down public.submissions RLS and protect AI-controlled fields
-- Purpose: Restrict authenticated users from modifying AI-controlled fields (ai_verdict, verified_at),
--          prevent cross-user submission access, block unauthorized submission updates and deletions,
--          and restrict INSERTs so clients cannot forge approved verification states.
-- Date: 2026-10-04

-- ============================================================================
-- STEP 1: REVOKE DANGEROUS TABLE PRIVILEGES FROM authenticated ROLE
-- ============================================================================

-- Revoke UPDATE and DELETE privileges from authenticated users.
-- Submissions cannot be updated or deleted directly by client roles.
REVOKE UPDATE, DELETE ON public.submissions FROM authenticated;

-- Ensure SELECT and INSERT privileges are granted to authenticated
GRANT SELECT, INSERT ON public.submissions TO authenticated;

-- ============================================================================
-- STEP 2: RECONFIGURE ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Remove old policies
DROP POLICY IF EXISTS "Users can view submissions for their tasks" ON public.submissions;
DROP POLICY IF EXISTS "Users can insert submissions for their tasks" ON public.submissions;
DROP POLICY IF EXISTS "Users can update submissions for their tasks" ON public.submissions;
DROP POLICY IF EXISTS "Users can delete submissions for their tasks" ON public.submissions;

-- 1. SELECT policy: Users can view only submissions associated with their own tasks
CREATE POLICY "Users can view submissions for their tasks" ON public.submissions
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.tasks
            WHERE public.tasks.id = task_id
              AND public.tasks.user_id = auth.uid()
        )
    );

-- 2. INSERT policy: Users can insert submissions only for their own tasks,
--    and cannot forge ai_verdict (must be NULL or 'pending') or verified_at (must be NULL)
CREATE POLICY "Users can insert submissions for their tasks" ON public.submissions
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.tasks
            WHERE public.tasks.id = task_id
              AND public.tasks.user_id = auth.uid()
        )
        AND (ai_verdict IS NULL OR ai_verdict = 'pending')
        AND verified_at IS NULL
    );

-- 3. UPDATE policy: DENIED for authenticated users
-- All submission fields (ai_verdict, verified_at, photo_url, task_id, id, submitted_at)
-- are server/AI-controlled or immutable once submitted.
-- No UPDATE policy is created for the authenticated role.

-- 4. DELETE policy: DENIED for authenticated users
-- Submissions cannot be deleted directly by clients; no DELETE policy is created.
