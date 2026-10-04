-- Migration: Lock down public.tasks RLS and protect server-controlled fields
-- Purpose: Restrict authenticated users to modifying only user-controlled fields (title, subject)
--          and prevent manipulation of server-controlled fields (id, user_id, xp_value, status, created_at, updated_at).
-- Date: 2026-10-04

-- ============================================================================
-- STEP 1: REVOKE DANGEROUS TABLE PRIVILEGES FROM authenticated ROLE
-- ============================================================================

-- Revoke broad UPDATE and DELETE privileges from authenticated users.
REVOKE UPDATE, DELETE ON public.tasks FROM authenticated;

-- ============================================================================
-- STEP 2: GRANT RESTRICTED COLUMN-LEVEL UPDATE PRIVILEGES
-- ============================================================================

-- Allow authenticated users to update ONLY legitimate user-editable fields (title, subject).
-- Server-controlled fields (id, user_id, xp_value, status, created_at, updated_at) cannot be updated by clients.
GRANT UPDATE(title, subject) ON public.tasks TO authenticated;

-- Ensure SELECT and INSERT privileges are granted to authenticated
GRANT SELECT, INSERT ON public.tasks TO authenticated;

-- ============================================================================
-- STEP 3: RECONFIGURE ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Remove old overly-broad policies
DROP POLICY IF EXISTS "Users can view their own tasks" ON public.tasks;
DROP POLICY IF EXISTS "Users can insert their own tasks" ON public.tasks;
DROP POLICY IF EXISTS "Users can update their own tasks" ON public.tasks;
DROP POLICY IF EXISTS "Users can delete their own tasks" ON public.tasks;

-- 1. SELECT policy: Users can view only their own tasks
CREATE POLICY "Users can view their own tasks" ON public.tasks
    FOR SELECT
    USING (auth.uid() = user_id);

-- 2. INSERT policy: Users can insert tasks for themselves only, with pending status
CREATE POLICY "Users can insert their own tasks" ON public.tasks
    FOR INSERT
    WITH CHECK (
        auth.uid() = user_id
        AND (status IS NULL OR status = 'pending')
    );

-- 3. UPDATE policy: Users can update only their own tasks (rows)
-- Combined with column-level privileges, only title and subject can be changed
CREATE POLICY "Users can update their own tasks" ON public.tasks
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 4. DELETE policy: DENIED for authenticated users
-- Direct task deletion by clients is prohibited; no DELETE policy is created.
