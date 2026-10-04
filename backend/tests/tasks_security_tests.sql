-- TEST SUITE: Security Verification for public.tasks RLS and Column Security
-- Purpose: Verify that public.tasks RLS and column privileges prevent authenticated clients
--          from manipulating server-controlled task fields (xp_value, status, user_id, id, created_at, updated_at),
--          prevent cross-user task access/modification, and block unauthorized deletion.
--
-- File: backend/tests/tasks_security_tests.sql
-- Run in Supabase SQL editor as postgres.

-- ============================================================================
-- SECTION 1: STRUCTURAL TESTS (Catalog Queries)
-- ============================================================================

-- TEST S1: Verify RLS is enabled on public.tasks
SELECT
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'tasks' AND schemaname = 'public';

-- TEST S2: Verify active RLS policies on public.tasks
SELECT
    policyname,
    permissive,
    cmd as operation,
    roles,
    qual as using_expression,
    with_check
FROM pg_policies
WHERE tablename = 'tasks' AND schemaname = 'public'
ORDER BY cmd, policyname;

-- TEST S3: Verify UPDATE column privileges on public.tasks for authenticated role
SELECT
    table_name,
    column_name,
    privilege_type
FROM information_schema.column_privileges
WHERE table_name = 'tasks'
  AND table_schema = 'public'
  AND grantee = 'authenticated'
  AND privilege_type = 'UPDATE'
ORDER BY column_name;

-- ============================================================================
-- SECTION 2: EXECUTABLE SECURITY ATTACK & PERMISSION TESTS
-- ============================================================================
-- The following DO $$ block executes simulated client actions under 'authenticated'
-- role with simulated auth.uid() JWT claims.

DO $$
DECLARE
    v_user_1 UUID := '11111111-1111-4111-a111-111111111111';
    v_user_2 UUID := '22222222-2222-4222-a222-222222222222';
    v_task_1_id UUID := '33333333-3333-4333-a333-333333333333';
    v_task_2_id UUID := '44444444-4444-4444-a444-444444444444';
    v_read_count INTEGER;
    v_updated_count INTEGER;
BEGIN
    RAISE NOTICE '=== SETUP: Creating test users and initial tasks as postgres ===';

    -- Ensure test users exist in public.users
    INSERT INTO public.users (id, name, total_xp, rank)
    VALUES
        (v_user_1, 'Task Security Test User 1', 0, 'E'),
        (v_user_2, 'Task Security Test User 2', 0, 'E')
    ON CONFLICT (id) DO NOTHING;

    -- Clean up previous test tasks if any
    DELETE FROM public.tasks WHERE id IN (v_task_1_id, v_task_2_id);

    -- Insert initial tasks directly as postgres (bypass RLS)
    INSERT INTO public.tasks (id, user_id, title, subject, xp_value, status)
    VALUES
        (v_task_1_id, v_user_1, 'Original Title 1', 'Physics', 50, 'pending'),
        (v_task_2_id, v_user_2, 'Original Title 2', 'Chemistry', 100, 'pending');

    RAISE NOTICE '=== TEST 1: Allowed UPDATE (User 1 updating own task title/subject) ===';
    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    UPDATE public.tasks
    SET title = 'Updated Title 1', subject = 'Advanced Physics'
    WHERE id = v_task_1_id;

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count = 1 THEN
        RAISE NOTICE 'PASS: User 1 successfully updated own task title and subject';
    ELSE
        RAISE EXCEPTION 'FAIL: User 1 could not update own task title/subject';
    END IF;

    -- Switch back to postgres role to verify changes
    SET LOCAL ROLE postgres;
    PERFORM set_config('request.jwt.claim.sub', '', true);

    RAISE NOTICE '=== TEST 2: Blocked UPDATE (User 1 attempting to alter xp_value) ===';
    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.tasks SET xp_value = 999999 WHERE id = v_task_1_id;
        RAISE EXCEPTION 'FAIL: xp_value update succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Column-level privilege denied xp_value update';
    END;

    RAISE NOTICE '=== TEST 3: Blocked UPDATE (User 1 attempting to alter status to approved) ===';
    BEGIN
        UPDATE public.tasks SET status = 'approved' WHERE id = v_task_1_id;
        RAISE EXCEPTION 'FAIL: status update succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Column-level privilege denied status update';
    END;

    RAISE NOTICE '=== TEST 4: Blocked UPDATE (User 1 attempting to reassign ownership user_id) ===';
    BEGIN
        UPDATE public.tasks SET user_id = v_user_2 WHERE id = v_task_1_id;
        RAISE EXCEPTION 'FAIL: user_id update succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Column-level privilege denied user_id update';
    END;

    RAISE NOTICE '=== TEST 5: Blocked Cross-User UPDATE (User 1 updating User 2 task title) ===';
    UPDATE public.tasks SET title = 'Hacked Title' WHERE id = v_task_2_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count = 0 THEN
        RAISE NOTICE 'PASS: RLS policy prevented User 1 from updating User 2 task';
    ELSE
        RAISE EXCEPTION 'FAIL: User 1 successfully updated User 2 task';
    END IF;

    RAISE NOTICE '=== TEST 6: Blocked Cross-User SELECT (User 1 attempting to read User 2 task) ===';
    SELECT COUNT(*) INTO v_read_count FROM public.tasks WHERE id = v_task_2_id;
    IF v_read_count = 0 THEN
        RAISE NOTICE 'PASS: RLS policy prevented User 1 from viewing User 2 task';
    ELSE
        RAISE EXCEPTION 'FAIL: User 1 could read User 2 task';
    END IF;

    RAISE NOTICE '=== TEST 7: Blocked INSERT (User 1 attempting to insert task for User 2) ===';
    BEGIN
        INSERT INTO public.tasks (user_id, title, subject, xp_value)
        VALUES (v_user_2, 'Malicious Task', 'Math', 50);
        RAISE EXCEPTION 'FAIL: Insertion for another user_id succeeded unexpectedly';
    EXCEPTION WHEN invalid_row_security_violation OR check_violation THEN
        RAISE NOTICE 'PASS: RLS WITH CHECK policy prevented task insertion for another user';
    END;

    RAISE NOTICE '=== TEST 8: Blocked INSERT (User 1 attempting to insert task with approved status) ===';
    BEGIN
        INSERT INTO public.tasks (user_id, title, subject, xp_value, status)
        VALUES (v_user_1, 'Forged Approved Task', 'Math', 50, 'approved');
        RAISE EXCEPTION 'FAIL: Insertion with status=approved succeeded unexpectedly';
    EXCEPTION WHEN invalid_row_security_violation OR check_violation THEN
        RAISE NOTICE 'PASS: RLS WITH CHECK policy prevented task insertion with status=approved';
    END;

    RAISE NOTICE '=== TEST 9: Blocked DELETE (User 1 attempting to delete own task) ===';
    BEGIN
        DELETE FROM public.tasks WHERE id = v_task_1_id;
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        IF v_updated_count = 0 THEN
            RAISE NOTICE 'PASS: DELETE privilege/policy denied task deletion';
        ELSE
            RAISE EXCEPTION 'FAIL: User 1 successfully deleted own task';
        END IF;
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: DELETE permission denied for authenticated role';
    END;

    RAISE NOTICE '=== CLEANUP: Removing test fixtures as postgres ===';
    SET LOCAL ROLE postgres;
    PERFORM set_config('request.jwt.claim.sub', '', true);

    DELETE FROM public.tasks WHERE id IN (v_task_1_id, v_task_2_id);
    DELETE FROM public.users WHERE id IN (v_user_1, v_user_2);

    RAISE NOTICE '=== ALL TASK SECURITY TESTS PASSED SUCCESSFULLY ===';
END $$;
