-- TEST SUITE: Security Verification for public.tasks RLS and Column Security
-- Purpose: Verify that public.tasks RLS, DAC table privileges, and column privileges:
--          1. Completely deny direct INSERT privileges to authenticated users (preventing xp_value forging).
--          2. Prevent manipulation of server-controlled task fields (xp_value, status, user_id, id, created_at, updated_at).
--          3. Prevent cross-user task access/modification via RLS.
--          4. Completely deny direct DELETE privileges to authenticated users.
--          5. Allow authenticated users to update ONLY legitimate fields (title, subject) on their own tasks.
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
-- Expected: SELECT and UPDATE policies exist; NO INSERT or DELETE policies exist for authenticated
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

-- TEST S3: Verify Table Privileges for authenticated role on public.tasks
-- Expected: SELECT privilege exists; INSERT, UPDATE, DELETE table-level privileges are NOT present
SELECT
    grantee,
    privilege_type
FROM information_schema.table_privileges
WHERE table_name = 'tasks'
  AND table_schema = 'public'
  AND grantee = 'authenticated'
ORDER BY privilege_type;

-- TEST S4: Verify Column Privileges on public.tasks for authenticated role
-- Expected: UPDATE privilege granted ONLY on title and subject
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
-- Executable PL/pgSQL DO $$ block testing role-based permission boundaries.
-- Role simulation uses 'SET ROLE authenticated' combined with Supabase JWT GUC claims.

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

    -- Insert initial tasks directly as postgres (trusted server role)
    INSERT INTO public.tasks (id, user_id, title, subject, xp_value, status)
    VALUES
        (v_task_1_id, v_user_1, 'Original Title 1', 'Physics', 50, 'pending'),
        (v_task_2_id, v_user_2, 'Original Title 2', 'Chemistry', 100, 'pending');

    -- ========================================================================
    -- CATEGORY 1: INSERT PRIVILEGE DENIAL & XP FORGERY PREVENTION
    -- ========================================================================

    RAISE NOTICE '=== TEST A1: Blocked INSERT (Authenticated client attempting standard task INSERT) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        INSERT INTO public.tasks (user_id, title, subject, xp_value)
        VALUES (v_user_1, 'Standard User Task', 'Physics', 50);
        RAISE EXCEPTION 'FAIL: Direct client INSERT succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Permission denied (DAC table privilege prevents authenticated INSERT)';
    END;

    RESET ROLE;

    RAISE NOTICE '=== TEST A2: Blocked INSERT Regression Test (Forged xp_value attempt) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        INSERT INTO public.tasks (user_id, title, subject, xp_value, status)
        VALUES (v_user_1, 'Forged High XP Task', 'Math', 999999, 'approved');
        RAISE EXCEPTION 'FAIL: Client task creation with forged xp_value succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Permission denied (Client cannot choose arbitrary xp_value via INSERT)';
    END;

    RESET ROLE;

    -- ========================================================================
    -- CATEGORY 2: ALLOWED vs BLOCKED COLUMN UPDATES
    -- ========================================================================

    RAISE NOTICE '=== TEST A3: Allowed UPDATE (User 1 updating own task title/subject) ===';
    SET ROLE authenticated;
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

    RESET ROLE;

    RAISE NOTICE '=== TEST A4: Blocked UPDATE (User 1 attempting to alter xp_value) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.tasks SET xp_value = 999999 WHERE id = v_task_1_id;
        RAISE EXCEPTION 'FAIL: xp_value update succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Column-level privilege denied xp_value update';
    END;

    RESET ROLE;

    RAISE NOTICE '=== TEST A5: Blocked UPDATE (User 1 attempting to alter status to approved) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.tasks SET status = 'approved' WHERE id = v_task_1_id;
        RAISE EXCEPTION 'FAIL: status update succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Column-level privilege denied status update';
    END;

    RESET ROLE;

    RAISE NOTICE '=== TEST A6: Blocked UPDATE (User 1 attempting to reassign ownership user_id) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.tasks SET user_id = v_user_2 WHERE id = v_task_1_id;
        RAISE EXCEPTION 'FAIL: user_id update succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Column-level privilege denied user_id update';
    END;

    RESET ROLE;

    -- ========================================================================
    -- CATEGORY 3: ROW LEVEL SECURITY (RLS) CROSS-USER ACCESS DENIAL
    -- ========================================================================

    RAISE NOTICE '=== TEST A7: Blocked Cross-User UPDATE (User 1 updating User 2 task title) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    UPDATE public.tasks SET title = 'Hacked Title' WHERE id = v_task_2_id;
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count = 0 THEN
        RAISE NOTICE 'PASS: RLS policy prevented User 1 from updating User 2 task';
    ELSE
        RAISE EXCEPTION 'FAIL: User 1 successfully updated User 2 task';
    END IF;

    RESET ROLE;

    RAISE NOTICE '=== TEST A8: Blocked Cross-User SELECT (User 1 attempting to read User 2 task) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    SELECT COUNT(*) INTO v_read_count FROM public.tasks WHERE id = v_task_2_id;
    IF v_read_count = 0 THEN
        RAISE NOTICE 'PASS: RLS policy prevented User 1 from viewing User 2 task';
    ELSE
        RAISE EXCEPTION 'FAIL: User 1 could read User 2 task';
    END IF;

    RESET ROLE;

    -- ========================================================================
    -- CATEGORY 4: DELETE PRIVILEGE DENIAL
    -- ========================================================================

    RAISE NOTICE '=== TEST A9: Blocked DELETE (User 1 attempting to delete own task) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        DELETE FROM public.tasks WHERE id = v_task_1_id;
        RAISE EXCEPTION 'FAIL: Direct client DELETE succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Permission denied (DAC table privilege prevents authenticated DELETE)';
    END;

    RESET ROLE;

    -- ========================================================================
    -- CLEANUP & TEARDOWN
    -- ========================================================================

    RAISE NOTICE '=== CLEANUP: Removing test fixtures as postgres ===';
    PERFORM set_config('request.jwt.claim.sub', '', true);

    DELETE FROM public.tasks WHERE id IN (v_task_1_id, v_task_2_id);
    DELETE FROM public.users WHERE id IN (v_user_1, v_user_2);

    RAISE NOTICE '=== ALL TASK SECURITY TESTS PASSED SUCCESSFULLY ===';
END $$;
