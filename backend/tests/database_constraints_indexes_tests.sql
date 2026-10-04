-- TEST SUITE: Database Constraints and Indexes Verification
-- Purpose: Verify that Task 7 constraints and indexes are correctly implemented
--          and that existing data-integrity constraints remain intact.
-- File: backend/tests/database_constraints_indexes_tests.sql
-- Run in Supabase SQL editor as postgres.

-- ============================================================================
-- SECTION 1: CONSTRAINT TESTS (Data Integrity)
-- ============================================================================

-- TEST C1: users.total_xp >= 0 constraint exists and rejects negative values
DO $$
DECLARE
    v_user_id UUID := 'c0000000-0000-4000-0000-000000000001';
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

    -- Create test user first
    INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
    VALUES (v_user_id, 'c1-test@example.com', 'dummy', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
    VALUES (v_user_id, 'C1 Test User', 'E', 0, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    -- Attempt to set negative total_xp
    BEGIN
        UPDATE public.users SET total_xp = -1 WHERE id = v_user_id;
        RAISE EXCEPTION 'FAIL: Negative total_xp was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: Constraint rejected negative total_xp (-1)';
    END;

    -- Cleanup
    DELETE FROM public.users WHERE id = v_user_id;
    DELETE FROM auth.users WHERE id = v_user_id;
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

-- TEST I1: Composite index xp_log(user_id, created_at DESC) exists with correct definition
DO $$
DECLARE
    v_index_found BOOLEAN := FALSE;
    v_columns TEXT;
    v_column_count INTEGER;
BEGIN
    RAISE NOTICE '=== TEST I1: Composite index xp_log(user_id, created_at DESC) definition ===';

    -- Verify index exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'xp_log'
          AND indexname = 'idx_xp_log_user_id_created_at'
    ) THEN
        RAISE EXCEPTION 'FAIL: Index idx_xp_log_user_id_created_at does not exist';
    END IF;

    -- Verify index has exactly 2 columns
    SELECT COUNT(*)
    INTO v_column_count
    FROM pg_index idx
    JOIN pg_attribute attr ON attr.attrelid = idx.indrelid
    WHERE idx.indexrelname = 'idx_xp_log_user_id_created_at'
      AND attr.attnum = ANY(idx.indkey);

    IF v_column_count <> 2 THEN
        RAISE EXCEPTION 'FAIL: Index has % columns, expected 2', v_column_count;
    END IF;

    -- Verify columns are user_id and created_at in correct order
    SELECT STRING_AGG(attname, ', ' ORDER BY attnum)
    INTO v_columns
    FROM (
        SELECT attr.attname, array_position(idx.indkey, attr.attnum) AS attnum
        FROM pg_index idx
        JOIN pg_attribute attr ON attr.attrelid = idx.indrelid
        WHERE idx.indexrelname = 'idx_xp_log_user_id_created_at'
          AND attr.attnum = ANY(idx.indkey)
    ) sub
    ORDER BY attnum;

    IF v_columns NOT LIKE 'user_id, created_at%' THEN
        RAISE EXCEPTION 'FAIL: Index columns are (%), expected (user_id, created_at)', v_columns;
    END IF;

    -- Verify created_at is DESC (indexdef contains DESC for the second column)
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'xp_log'
          AND indexname = 'idx_xp_log_user_id_created_at'
          AND indexdef LIKE '%DESC%'
    ) THEN
        RAISE EXCEPTION 'FAIL: Index does not use DESC order for created_at column';
    END IF;

    RAISE NOTICE 'PASS: Index idx_xp_log_user_id_created_at has correct definition (user_id, created_at DESC)';
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

-- TEST R3: Authenticated cannot modify server-controlled task fields (Task 3 security)
DO $$
DECLARE
    v_user_1 UUID := 'c0000000-0000-4000-0000-000000000009';
    v_user_2 UUID := 'c0000000-0000-4000-0000-00000000000a';
    v_task_id UUID := 'd0000000-0000-4000-0000-000000000001';
    v_updated_count INTEGER;
BEGIN
    RAISE NOTICE '=== TEST R3: Authenticated cannot modify server-controlled task fields (Task 3 security) ===';

    -- Create test users
    INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
    VALUES
        (v_user_1, 'r3-user-1@example.com', 'dummy', NOW(), NOW(), NOW()),
        (v_user_2, 'r3-user-2@example.com', 'dummy', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
    VALUES
        (v_user_1, 'R3 Test User 1', 'E', 0, NOW(), NOW()),
        (v_user_2, 'R3 Test User 2', 'E', 50, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    -- Create task for user 1 as postgres
    INSERT INTO public.tasks (id, user_id, title, subject, xp_value, status)
    VALUES (v_task_id, v_user_1, 'Original Task', 'Physics', 100, 'pending')
    ON CONFLICT (id) DO NOTHING;

    -- Test 1: Cannot modify user_id
    RAISE NOTICE '  Subtest R3a: Attempting to modify user_id...';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.tasks SET user_id = v_user_2 WHERE id = v_task_id;
        RAISE EXCEPTION 'FAIL: Authenticated could modify user_id';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '  PASS: Cannot modify user_id';
    END;

    RESET ROLE;

    -- Test 2: Cannot modify xp_value
    RAISE NOTICE '  Subtest R3b: Attempting to modify xp_value...';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.tasks SET xp_value = 999999 WHERE id = v_task_id;
        RAISE EXCEPTION 'FAIL: Authenticated could modify xp_value';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '  PASS: Cannot modify xp_value';
    END;

    RESET ROLE;

    -- Test 3: Cannot modify status
    RAISE NOTICE '  Subtest R3c: Attempting to modify status...';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.tasks SET status = 'approved' WHERE id = v_task_id;
        RAISE EXCEPTION 'FAIL: Authenticated could modify status';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '  PASS: Cannot modify status';
    END;

    RESET ROLE;

    -- Verify task is unchanged
    DECLARE
        v_task_user_id UUID;
        v_task_xp_value INTEGER;
        v_task_status TEXT;
    BEGIN
        SELECT user_id, xp_value, status
        INTO v_task_user_id, v_task_xp_value, v_task_status
        FROM public.tasks WHERE id = v_task_id;

        IF v_task_user_id = v_user_1 AND v_task_xp_value = 100 AND v_task_status = 'pending' THEN
            RAISE NOTICE 'PASS: Task fields remain unchanged after attack attempts';
        ELSE
            RAISE EXCEPTION 'FAIL: Task was modified despite privilege restrictions';
        END IF;
    END;

    -- Cleanup
    DELETE FROM public.tasks WHERE id = v_task_id;
    DELETE FROM public.users WHERE id IN (v_user_1, v_user_2);
    DELETE FROM auth.users WHERE id IN (v_user_1, v_user_2);
END $$;

-- TEST R4: Authenticated cannot modify server-controlled submission fields (Task 4 security)
DO $$
DECLARE
    v_user_1 UUID := 'c0000000-0000-4000-0000-00000000000b';
    v_user_2 UUID := 'c0000000-0000-4000-0000-00000000000c';
    v_task_id UUID := 'd0000000-0000-4000-0000-000000000002';
    v_submission_id UUID := 'e0000000-0000-4000-0000-000000000001';
BEGIN
    RAISE NOTICE '=== TEST R4: Authenticated cannot modify server-controlled submission fields (Task 4 security) ===';

    -- Create test users
    INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
    VALUES
        (v_user_1, 'r4-user-1@example.com', 'dummy', NOW(), NOW(), NOW()),
        (v_user_2, 'r4-user-2@example.com', 'dummy', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
    VALUES
        (v_user_1, 'R4 Test User 1', 'E', 0, NOW(), NOW()),
        (v_user_2, 'R4 Test User 2', 'E', 50, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    -- Create task for user 1
    INSERT INTO public.tasks (id, user_id, title, subject, xp_value, status)
    VALUES (v_task_id, v_user_1, 'Test Task', 'Math', 50, 'pending')
    ON CONFLICT (id) DO NOTHING;

    -- Create submission for user 1's task
    INSERT INTO public.submissions (id, task_id, photo_url, ai_verdict, submitted_at)
    VALUES (v_submission_id, v_task_id, 'https://example.com/proof.jpg', 'pending', NOW())
    ON CONFLICT (id) DO NOTHING;

    -- Test 1: Cannot modify ai_verdict
    RAISE NOTICE '  Subtest R4a: Attempting to modify ai_verdict...';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.submissions SET ai_verdict = 'approved' WHERE id = v_submission_id;
        RAISE EXCEPTION 'FAIL: Authenticated could modify ai_verdict';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '  PASS: Cannot modify ai_verdict';
    END;

    RESET ROLE;

    -- Test 2: Cannot modify verified_at
    RAISE NOTICE '  Subtest R4b: Attempting to modify verified_at...';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.submissions SET verified_at = NOW() WHERE id = v_submission_id;
        RAISE EXCEPTION 'FAIL: Authenticated could modify verified_at';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '  PASS: Cannot modify verified_at';
    END;

    RESET ROLE;

    -- Test 3: Cannot modify submitted_at
    RAISE NOTICE '  Subtest R4c: Attempting to modify submitted_at...';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.submissions SET submitted_at = NOW() - INTERVAL '1 day' WHERE id = v_submission_id;
        RAISE EXCEPTION 'FAIL: Authenticated could modify submitted_at';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '  PASS: Cannot modify submitted_at';
    END;

    RESET ROLE;

    -- Test 4: Cannot modify id
    RAISE NOTICE '  Subtest R4d: Attempting to modify id...';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.submissions SET id = 'ffffffff-ffff-4fff-ffff-ffffffffffff' WHERE id = v_submission_id;
        RAISE EXCEPTION 'FAIL: Authenticated could modify id';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '  PASS: Cannot modify id';
    END;

    RESET ROLE;

    -- Verify submission is unchanged
    DECLARE
        v_verdict TEXT;
        v_verified_at TIMESTAMP WITH TIME ZONE;
        v_sub_id UUID;
    BEGIN
        SELECT ai_verdict, verified_at, id
        INTO v_verdict, v_verified_at, v_sub_id
        FROM public.submissions WHERE id = v_submission_id;

        IF v_verdict = 'pending' AND v_verified_at IS NULL AND v_sub_id = v_submission_id THEN
            RAISE NOTICE 'PASS: Submission fields remain unchanged after attack attempts';
        ELSE
            RAISE EXCEPTION 'FAIL: Submission was modified despite privilege restrictions';
        END IF;
    END;

    -- Cleanup
    DELETE FROM public.submissions WHERE id = v_submission_id;
    DELETE FROM public.tasks WHERE id = v_task_id;
    DELETE FROM public.users WHERE id IN (v_user_1, v_user_2);
    DELETE FROM auth.users WHERE id IN (v_user_1, v_user_2);
END $$;

-- ============================================================================
-- FINAL VERIFICATION
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '=== ALL CONSTRAINT AND INDEX TESTS COMPLETED SUCCESSFULLY ===';
END $$;
