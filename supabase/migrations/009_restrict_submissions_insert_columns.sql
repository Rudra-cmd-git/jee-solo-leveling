-- Migration: Restrict authenticated INSERT privileges to only task_id and photo_url
-- Purpose: Close the column-level privilege hole where authenticated users could
--          explicitly provide server-controlled fields (id, submitted_at) or forged
--          AI verdicts (ai_verdict, verified_at).
-- Date: 2026-10-04
--
-- After this migration:
-- - authenticated users can INSERT only (task_id, photo_url)
-- - Database automatically generates id, submitted_at
-- - ai_verdict and verified_at remain server-controlled (NULL on creation)
-- - RLS continues to enforce ownership and verdict/timestamp validation

-- ============================================================================
-- RESTRICT INSERT PRIVILEGES TO SPECIFIC COLUMNS ONLY
-- ============================================================================

-- Revoke the blanket INSERT privilege granted in migration 008
REVOKE INSERT ON public.submissions FROM authenticated;

-- Grant INSERT privilege only on legitimate client-controlled columns
GRANT INSERT (task_id, photo_url) ON public.submissions TO authenticated;
