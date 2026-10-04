-- TEST SUITE: Security Verification for public.submissions RLS and AI-Controlled Fields
-- Purpose: Verify that public.submissions RLS and table/column privileges:
--          1. Prevent authenticated users from modifying AI-controlled fields (ai_verdict, verified_at).
--          2. Prevent cross-user submission reading and insertion.
--          3. Prevent insertion of forged approval states (ai_verdict='approved' or verified_at timestamp).
--          4. Deny direct authenticated UPDATE and DELETE operations completely.
--          5. Preserve trusted backend/service_role privileges to update AI verification verdicts.
--
-- File: backend/tests/submissions_security_tests.sql
-- Run in Supabase SQL editor as postgres.

-- ============================================================================
-- SECTION 1: STRUCTURAL TESTS (Catalog Queries)
-- ============================================================================

-- TEST S1: Verify RLS is enabled on public.submissions
SELECT
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'submissions' AND schemaname = 'public';

-- TEST S2: Verify active RLS policies on public.submissions
-- Expected: SELECT and INSERT policies exist; NO UPDATE or DELETE policies exist for authenticated
SELECT
    policyname,
    permissive,
    cmd as operation,
    roles,
    qual as using_expression,
    with_check
FROM pg_policies
WHERE tablename = 'submissions' AND schemaname = 'public'
ORDER BY cmd, policyname;

-- TEST S3: Verify Table Privileges for authenticated role on public.submissions
-- Expected: SELECT and INSERT privileges exist; UPDATE and DELETE table privileges are NOT present
SELECT
    grantee,
    privilege_type
FROM information_schema.table_privileges
WHERE table_name = 'submissions'
  AND table_schema = 'public'
  AND grantee = 'authenticated'
ORDER BY privilege_type;

-- TEST S4: Verify Column Privileges on public.submissions for authenticated role
-- Expected: NO UPDATE privilege granted on ANY column to authenticated
SELECT
    table_name,
    column_name,
    privilege_type
FROM information_schema.column_privileges
WHERE table_name = 'submissions'
  AND table_schema = 'public'
  AND grantee = 'authenticated'
  AND privilege_type = 'UPDATE'
ORDER BY column_name;

-- ============================================================================
-- SECTION 2: EXECUTABLE SECURITY ATTACK & PERMISSION TESTS
-- ============================================================================
-- Executable PL/pgSQL DO $$ block testing role-based permission boundaries.
-- Role simulation uses 'SET ROLE authenticated' combined with Supabase JWT GUC claims.

DO $$
DECLARE
    v_user_1 UUID := '11111111-1111-4111-a111-111111111111';
    v_user_2 UUID := '22222222-2222-4222-a222-222222222222';
    v_task_1_id UUID := '33333333-3333-4333-a333-333333333333';
    v_task_2_id UUID := '44444444-4444-4444-a444-444444444444';
    v_sub_1_id UUID := '55555555-5555-4555-a555-555555555555';
    v_sub_2_id UUID := '66666666-6666-4666-a666-666666666666';
    v_new_sub_id UUID := '77777777-7777-4777-a777-777777777777';
    v_read_count INTEGER;
    v_updated_count INTEGER;
BEGIN
    RAISE NOTICE '=== SETUP: Creating test users, tasks, and initial submissions as postgres ===';

    -- Ensure test users exist in public.users
    INSERT INTO public.users (id, name, total_xp, rank)
    VALUES
        (v_user_1, 'Submission Test User 1', 0, 'E'),
        (v_user_2, 'Submission Test User 2', 0, 'E')
    ON CONFLICT (id) DO NOTHING;

    -- Clean up previous test tasks and submissions if any
    DELETE FROM public.submissions WHERE id IN (v_sub_1_id, v_sub_2_id, v_new_sub_id);
    DELETE FROM public.tasks WHERE id IN (v_task_1_id, v_task_2_id);

    -- Insert initial tasks directly as postgres
    INSERT INTO public.tasks (id, user_id, title, subject, xp_value, status)
    VALUES
        (v_task_1_id, v_user_1, 'Physics Study', 'Physics', 50, 'pending'),
        (v_task_2_id, v_user_2, 'Chemistry Study', 'Chemistry', 100, 'pending');

    -- Insert initial submissions directly as postgres
    INSERT INTO public.submissions (id, task_id, photo_url, ai_verdict, submitted_at)
    VALUES
        (v_sub_1_id, v_task_1_id, 'https://example.com/proof1.jpg', 'pending', NOW()),
        (v_sub_2_id, v_task_2_id, 'https://example.com/proof2.jpg', 'pending', NOW());

    -- ========================================================================
    -- CATEGORY 1: SELECT SECURITY (OWNERSHIP RESTRICTIONS)
    -- ========================================================================

    RAISE NOTICE '=== TEST A1: Allowed SELECT (User 1 reading own submission for Task 1) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    SELECT COUNT(*) INTO v_read_count FROM public.submissions WHERE id = v_sub_1_id;
    IF v_read_count = 1 THEN
        RAISE NOTICE 'PASS: User 1 can view submission for own task';
    ELSE
        RAISE EXCEPTION 'FAIL: User 1 could not view submission for own task';
    END IF;

    RESET ROLE;

    RAISE NOTICE '=== TEST A2: Blocked Cross-User SELECT (User 1 reading User 2 submission) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    SELECT COUNT(*) INTO v_read_count FROM public.submissions WHERE id = v_sub_2_id;
    IF v_read_count = 0 THEN
        RAISE NOTICE 'PASS: RLS policy prevented User 1 from viewing User 2 submission';
    ELSE
        RAISE EXCEPTION 'FAIL: User 1 could read User 2 submission';
    END IF;

    RESET ROLE;

    -- ========================================================================
    -- CATEGORY 2: INSERT SECURITY (STATUS FORGERY PREVENTION)
    -- ========================================================================

    RAISE NOTICE '=== TEST A3: Allowed INSERT (User 1 inserting pending submission for own task) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    INSERT INTO public.submissions (id, task_id, photo_url, ai_verdict)
    VALUES (v_new_sub_id, v_task_1_id, 'https://example.com/proof_new.jpg', 'pending');

    RAISE NOTICE 'PASS: User 1 successfully created pending submission for own task';

    RESET ROLE;

    RAISE NOTICE '=== TEST A4: Blocked Cross-User INSERT (User 1 inserting submission for User 2 task) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        INSERT INTO public.submissions (task_id, photo_url, ai_verdict)
        VALUES (v_task_2_id, 'https://example.com/malicious.jpg', 'pending');
        RAISE EXCEPTION 'FAIL: Insertion for another user task succeeded unexpectedly';
    EXCEPTION WHEN invalid_row_security_violation OR check_violation THEN
        RAISE NOTICE 'PASS: RLS WITH CHECK policy prevented submission insertion for another user task';
    END;

    RESET ROLE;

    RAISE NOTICE '=== TEST A5: Blocked INSERT Regression Test (Forged ai_verdict = approved) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        INSERT INTO public.submissions (task_id, photo_url, ai_verdict)
        VALUES (v_task_1_id, 'https://example.com/forged.jpg', 'approved');
        RAISE EXCEPTION 'FAIL: Submission insertion with forged ai_verdict=approved succeeded unexpectedly';
    EXCEPTION WHEN invalid_row_security_violation OR check_violation THEN
        RAISE NOTICE 'PASS: RLS WITH CHECK policy prevented submission insertion with forged ai_verdict=approved';
    END;

    RESET ROLE;

    RAISE NOTICE '=== TEST A6: Blocked INSERT Regression Test (Forged verified_at timestamp) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        INSERT INTO public.submissions (task_id, photo_url, ai_verdict, verified_at)
        VALUES (v_task_1_id, 'https://example.com/forged_time.jpg', 'pending', NOW());
        RAISE EXCEPTION 'FAIL: Submission insertion with verified_at timestamp succeeded unexpectedly';
    EXCEPTION WHEN invalid_row_security_violation OR check_violation THEN
        RAISE NOTICE 'PASS: RLS WITH CHECK policy prevented submission insertion with verified_at timestamp';
    END;

    RESET ROLE;

    -- ========================================================================
    -- CATEGORY 3: UPDATE SECURITY (ALL CLIENT UPDATES DENIED)
    -- ========================================================================

    RAISE NOTICE '=== TEST A7: Blocked UPDATE (Authenticated client attempting to update ai_verdict) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.submissions SET ai_verdict = 'approved' WHERE id = v_sub_1_id;
        RAISE EXCEPTION 'FAIL: Client update on ai_verdict succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Permission denied (DAC table privilege prevents authenticated UPDATE)';
    END;

    RESET ROLE;

    RAISE NOTICE '=== TEST A8: Blocked UPDATE (Authenticated client attempting to update verified_at) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.submissions SET verified_at = NOW() WHERE id = v_sub_1_id;
        RAISE EXCEPTION 'FAIL: Client update on verified_at succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Permission denied (DAC table privilege prevents authenticated UPDATE)';
    END;

    RESET ROLE;

    RAISE NOTICE '=== TEST A9: Blocked UPDATE (Authenticated client attempting to update photo_url) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.submissions SET photo_url = 'https://example.com/hacked.jpg' WHERE id = v_sub_1_id;
        RAISE EXCEPTION 'FAIL: Client update on photo_url succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Permission denied (DAC table privilege prevents authenticated UPDATE)';
    END;

    RESET ROLE;

    -- ========================================================================
    -- CATEGORY 4: DELETE SECURITY (DIRECT CLIENT DELETION DENIED)
    -- ========================================================================

    RAISE NOTICE '=== TEST A10: Blocked DELETE (Authenticated client attempting to delete submission) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        DELETE FROM public.submissions WHERE id = v_sub_1_id;
        RAISE EXCEPTION 'FAIL: Direct client DELETE succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Permission denied (DAC table privilege prevents authenticated DELETE)';
    END;

    RESET ROLE;

    -- ========================================================================
    -- CATEGORY 5: TRUSTED BACKEND ACCESS (SERVICE ROLE BYPASS)
    -- ========================================================================

    RAISE NOTICE '=== TEST A11: Allowed Service Role UPDATE (Trusted backend setting AI verdict) ===';
    -- Executing as postgres / service_role (default)
    UPDATE public.submissions
    SET ai_verdict = 'approved', verified_at = NOW()
    WHERE id = v_sub_1_id;

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count = 1 THEN
        RAISE NOTICE 'PASS: Trusted backend/service_role successfully updated AI verdict and verified_at';
    ELSE
        RAISE EXCEPTION 'FAIL: Trusted backend could not update submission AI verdict';
    END IF;

    -- ========================================================================
    -- CLEANUP & TEARDOWN
    -- ========================================================================

    RAISE NOTICE '=== CLEANUP: Removing test fixtures as postgres ===';
    PERFORM set_config('request.jwt.claim.sub', '', true);

    DELETE FROM public.submissions WHERE id IN (v_sub_1_id, v_sub_2_id, v_new_sub_id);
    DELETE FROM public.tasks WHERE id IN (v_task_1_id, v_task_2_id);
    DELETE FROM public.users WHERE id IN (v_user_1, v_user_2);

    RAISE NOTICE '=== ALL SUBMISSION SECURITY TESTS PASSED SUCCESSFULLY ===';
END $$;
