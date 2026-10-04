-- TEST SUITE: Database Constraints and Indexes Verification
-- Purpose: Verify that Task 7 constraints and indexes are correctly implemented
--          and that existing data-integrity constraints remain intact.
-- File: backend/tests/database_constraints_indexes_tests.sql
-- Run in Supabase SQL editor as postgres.

-- ============================================================================
-- SECTION 1: CONSTRAINT TESTS (Data Integrity)
-- ============================================================================

-- TEST C1: users.total_xp >= 0 constraint exists and works
DO $$
BEGIN
    RAISE NOTICE '=== TEST C1: users.total_xp non-negative constraint ===';

    -- Verify constraint exists in catalog
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE table_schema = 'public'
          AND table_name = 'users'
          AND constraint_name = 'total_xp_non_negative'
    ) THEN
        RAISE EXCEPTION 'FAIL: Constraint total_xp_non_negative does not exist';
    END IF;

    RAISE NOTICE 'PASS: Constraint total_xp_non_negative exists';
END $$;

-- TEST C2: tasks.title not empty constraint exists
DO $$
BEGIN
    RAISE NOTICE '=== TEST C2: tasks.title not-empty constraint ===';

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE table_schema = 'public'
          AND table_name = 'tasks'
          AND constraint_name = 'title_not_empty'
    ) THEN
        RAISE EXCEPTION 'FAIL: Constraint title_not_empty does not exist';
    END IF;

    RAISE NOTICE 'PASS: Constraint title_not_empty exists';
END $$;

-- TEST C3: tasks.subject not empty constraint exists
DO $$
BEGIN
    RAISE NOTICE '=== TEST C3: tasks.subject not-empty constraint ===';

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE table_schema = 'public'
          AND table_name = 'tasks'
          AND constraint_name = 'subject_not_empty'
    ) THEN
        RAISE EXCEPTION 'FAIL: Constraint subject_not_empty does not exist';
    END IF;

    RAISE NOTICE 'PASS: Constraint subject_not_empty exists';
END $$;

-- TEST C4: submissions.photo_url not empty constraint exists
DO $$
BEGIN
    RAISE NOTICE '=== TEST C4: submissions.photo_url not-empty constraint ===';

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE table_schema = 'public'
          AND table_name = 'submissions'
          AND constraint_name = 'photo_url_not_empty'
    ) THEN
        RAISE EXCEPTION 'FAIL: Constraint photo_url_not_empty does not exist';
    END IF;

    RAISE NOTICE 'PASS: Constraint photo_url_not_empty exists';
END $$;

-- TEST C5: xp_log.reason not empty constraint exists
DO $$
BEGIN
    RAISE NOTICE '=== TEST C5: xp_log.reason not-empty constraint ===';

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE table_schema = 'public'
          AND table_name = 'xp_log'
          AND constraint_name = 'reason_not_empty'
    ) THEN
        RAISE EXCEPTION 'FAIL: Constraint reason_not_empty does not exist';
    END IF;

    RAISE NOTICE 'PASS: Constraint reason_not_empty exists';
END $$;

-- TEST C6: Whitespace-only task title is rejected
DO $$
DECLARE
    v_user_id UUID := 'c0000000-0000-4000-0000-000000000001';
BEGIN
    RAISE NOTICE '=== TEST C6: Whitespace-only title rejected ===';

    -- Create test user first
    INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
    VALUES (v_user_id, 'constraint-test-1@example.com', 'dummy', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
    VALUES (v_user_id, 'Constraint Test User', 'E', 0, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    -- Attempt to create task with whitespace-only title
    BEGIN
        INSERT INTO public.tasks (user_id, title, subject, xp_value)
        VALUES (v_user_id, '   ', 'Valid Subject', 50);
        RAISE EXCEPTION 'FAIL: Whitespace-only title was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: Whitespace-only title rejected by constraint';
    END;

    -- Cleanup
    DELETE FROM public.users WHERE id = v_user_id;
    DELETE FROM auth.users WHERE id = v_user_id;
END $$;

-- TEST C7: Whitespace-only task subject is rejected
DO $$
DECLARE
    v_user_id UUID := 'c0000000-0000-4000-0000-000000000002';
BEGIN
    RAISE NOTICE '=== TEST C7: Whitespace-only subject rejected ===';

    INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
    VALUES (v_user_id, 'constraint-test-2@example.com', 'dummy', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
    VALUES (v_user_id, 'Constraint Test User 2', 'E', 0, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    BEGIN
        INSERT INTO public.tasks (user_id, title, subject, xp_value)
        VALUES (v_user_id, 'Valid Title', '   ', 50);
        RAISE EXCEPTION 'FAIL: Whitespace-only subject was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: Whitespace-only subject rejected by constraint';
    END;

    DELETE FROM public.users WHERE id = v_user_id;
    DELETE FROM auth.users WHERE id = v_user_id;
END $$;

-- TEST C8: Whitespace-only submission photo_url is rejected
DO $$
DECLARE
    v_user_id UUID := 'c0000000-0000-4000-0000-000000000003';
    v_task_id UUID := 'd0000000-0000-4000-0000-000000000001';
BEGIN
    RAISE NOTICE '=== TEST C8: Whitespace-only photo_url rejected ===';

    INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
    VALUES (v_user_id, 'constraint-test-3@example.com', 'dummy', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
    VALUES (v_user_id, 'Constraint Test User 3', 'E', 0, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.tasks (id, user_id, title, subject, xp_value)
    VALUES (v_task_id, v_user_id, 'Test Task', 'Test Subject', 50)
    ON CONFLICT (id) DO NOTHING;

    BEGIN
        INSERT INTO public.submissions (task_id, photo_url)
        VALUES (v_task_id, '   ');
        RAISE EXCEPTION 'FAIL: Whitespace-only photo_url was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: Whitespace-only photo_url rejected by constraint';
    END;

    DELETE FROM public.submissions WHERE task_id = v_task_id;
    DELETE FROM public.tasks WHERE id = v_task_id;
    DELETE FROM public.users WHERE id = v_user_id;
    DELETE FROM auth.users WHERE id = v_user_id;
END $$;

-- TEST C9: Whitespace-only xp_log reason is rejected
DO $$
DECLARE
    v_user_id UUID := 'c0000000-0000-4000-0000-000000000004';
BEGIN
    RAISE NOTICE '=== TEST C9: Whitespace-only xp_log reason rejected ===';

    INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
    VALUES (v_user_id, 'constraint-test-4@example.com', 'dummy', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
    VALUES (v_user_id, 'Constraint Test User 4', 'E', 0, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    BEGIN
        INSERT INTO public.xp_log (user_id, xp_change, reason)
        VALUES (v_user_id, 100, '   ');
        RAISE EXCEPTION 'FAIL: Whitespace-only reason was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: Whitespace-only reason rejected by constraint';
    END;

    DELETE FROM public.users WHERE id = v_user_id;
    DELETE FROM auth.users WHERE id = v_user_id;
END $$;

-- TEST C10: Existing rank constraint still works
DO $$
DECLARE
    v_user_id UUID := 'c0000000-0000-4000-0000-000000000005';
BEGIN
    RAISE NOTICE '=== TEST C10: Existing rank constraint (regression test) ===';

    INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
    VALUES (v_user_id, 'constraint-test-5@example.com', 'dummy', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    BEGIN
        INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
        VALUES (v_user_id, 'Invalid Rank User', 'X', 0, NOW(), NOW());
        RAISE EXCEPTION 'FAIL: Invalid rank was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: Invalid rank rejected by existing constraint';
    END;

    DELETE FROM auth.users WHERE id = v_user_id;
END $$;

-- TEST C11: Existing xp_value > 0 constraint still works
DO $$
DECLARE
    v_user_id UUID := 'c0000000-0000-4000-0000-000000000006';
BEGIN
    RAISE NOTICE '=== TEST C11: Existing xp_value > 0 constraint (regression test) ===';

    INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
    VALUES (v_user_id, 'constraint-test-6@example.com', 'dummy', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
    VALUES (v_user_id, 'Task XP Test User', 'E', 0, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    BEGIN
        INSERT INTO public.tasks (user_id, title, subject, xp_value)
        VALUES (v_user_id, 'Zero XP Task', 'Subject', 0);
        RAISE EXCEPTION 'FAIL: Zero xp_value was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: Zero xp_value rejected by existing constraint';
    END;

    DELETE FROM public.users WHERE id = v_user_id;
    DELETE FROM auth.users WHERE id = v_user_id;
END $$;

-- ============================================================================
-- SECTION 2: INDEX TESTS
-- ============================================================================

-- TEST I1: Composite index xp_log(user_id, created_at) exists
DO $$
BEGIN
    RAISE NOTICE '=== TEST I1: Composite index xp_log(user_id, created_at) ===';

    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'xp_log'
          AND indexname = 'idx_xp_log_user_id_created_at'
    ) THEN
        RAISE EXCEPTION 'FAIL: Index idx_xp_log_user_id_created_at does not exist';
    END IF;

    RAISE NOTICE 'PASS: Index idx_xp_log_user_id_created_at exists';
END $$;

-- TEST I2: Verify all existing indexes are still present
DO $$
DECLARE
    v_expected_indexes TEXT[] := ARRAY[
        'idx_tasks_user_id',
        'idx_tasks_status',
        'idx_submissions_task_id',
        'idx_submissions_ai_verdict',
        'idx_xp_log_user_id',
        'idx_xp_log_created_at'
    ];
    v_index TEXT;
    v_missing_count INTEGER := 0;
BEGIN
    RAISE NOTICE '=== TEST I2: Existing indexes still present (regression test) ===';

    FOREACH v_index IN ARRAY v_expected_indexes LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes
            WHERE schemaname = 'public' AND indexname = v_index
        ) THEN
            RAISE NOTICE 'FAIL: Expected index % not found', v_index;
            v_missing_count := v_missing_count + 1;
        END IF;
    END LOOP;

    IF v_missing_count > 0 THEN
        RAISE EXCEPTION 'FAIL: % existing indexes are missing', v_missing_count;
    END IF;

    RAISE NOTICE 'PASS: All % existing indexes present', array_length(v_expected_indexes, 1);
END $$;

-- ============================================================================
-- SECTION 3: REGRESSION TESTS (Security Remains Intact)
-- ============================================================================

-- TEST R1: Authenticated cannot update users.total_xp (security regression)
DO $$
DECLARE
    v_user_id UUID := 'c0000000-0000-4000-0000-000000000007';
BEGIN
    RAISE NOTICE '=== TEST R1: Authenticated cannot update total_xp (regression) ===';

    INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
    VALUES (v_user_id, 'regression-test-1@example.com', 'dummy', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
    VALUES (v_user_id, 'Regression Test User', 'E', 0, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

    BEGIN
        UPDATE public.users SET total_xp = 999 WHERE id = v_user_id;
        RAISE EXCEPTION 'FAIL: Authenticated could update total_xp';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Authenticated blocked from updating total_xp';
    END;

    RESET ROLE;

    DELETE FROM public.users WHERE id = v_user_id;
    DELETE FROM auth.users WHERE id = v_user_id;
END $$;

-- TEST R2: Authenticated cannot insert into xp_log (security regression)
DO $$
DECLARE
    v_user_id UUID := 'c0000000-0000-4000-0000-000000000008';
BEGIN
    RAISE NOTICE '=== TEST R2: Authenticated cannot insert xp_log (regression) ===';

    INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
    VALUES (v_user_id, 'regression-test-2@example.com', 'dummy', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
    VALUES (v_user_id, 'Regression Test User 2', 'E', 0, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

    BEGIN
        INSERT INTO public.xp_log (user_id, xp_change, reason)
        VALUES (v_user_id, 100, 'hack');
        RAISE EXCEPTION 'FAIL: Authenticated could insert xp_log';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Authenticated blocked from inserting xp_log';
    END;

    RESET ROLE;

    DELETE FROM public.users WHERE id = v_user_id;
    DELETE FROM auth.users WHERE id = v_user_id;
END $$;

-- ============================================================================
-- FINAL VERIFICATION
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '=== ALL CONSTRAINT AND INDEX TESTS COMPLETED SUCCESSFULLY ===';
END $$;
