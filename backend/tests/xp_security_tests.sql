-- TEST SUITE: XP Security Verification
-- Purpose: Verify that the XP system is completely server-controlled and cannot
--          be manipulated by authenticated clients to award themselves arbitrary XP,
--          while trusted backend operations retain full capability to manage XP.
-- File: backend/tests/xp_security_tests.sql
-- Run in Supabase SQL editor as postgres.

-- ============================================================================
-- SECTION 1: STRUCTURAL TESTS (Catalog Assertions)
-- ============================================================================

-- TEST S1: Verify authenticated has NO UPDATE(total_xp)
DO $$
DECLARE
    v_has_total_xp_update BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.column_privileges
        WHERE table_schema = 'public'
          AND table_name = 'users'
          AND column_name = 'total_xp'
          AND grantee = 'authenticated'
          AND privilege_type = 'UPDATE'
    ) INTO v_has_total_xp_update;

    IF v_has_total_xp_update THEN
        RAISE EXCEPTION 'FAIL: authenticated should NOT have UPDATE(total_xp) privilege';
    END IF;

    RAISE NOTICE 'PASS: authenticated has NO UPDATE(total_xp) privilege';
END $$;

-- TEST S2: Verify authenticated has NO INSERT on xp_log
DO $$
DECLARE
    v_has_insert BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_privileges
        WHERE table_name = 'xp_log'
          AND table_schema = 'public'
          AND grantee = 'authenticated'
          AND privilege_type = 'INSERT'
    ) INTO v_has_insert;

    IF v_has_insert THEN
        RAISE EXCEPTION 'FAIL: authenticated should NOT have INSERT privilege on xp_log';
    END IF;

    RAISE NOTICE 'PASS: authenticated has NO INSERT privilege on xp_log';
END $$;

-- TEST S3: Verify authenticated has NO UPDATE on xp_log
DO $$
DECLARE
    v_has_update BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_privileges
        WHERE table_name = 'xp_log'
          AND table_schema = 'public'
          AND grantee = 'authenticated'
          AND privilege_type = 'UPDATE'
    ) INTO v_has_update;

    IF v_has_update THEN
        RAISE EXCEPTION 'FAIL: authenticated should NOT have UPDATE privilege on xp_log';
    END IF;

    RAISE NOTICE 'PASS: authenticated has NO UPDATE privilege on xp_log';
END $$;

-- TEST S4: Verify authenticated has NO DELETE on xp_log
DO $$
DECLARE
    v_has_delete BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_privileges
        WHERE table_name = 'xp_log'
          AND table_schema = 'public'
          AND grantee = 'authenticated'
          AND privilege_type = 'DELETE'
    ) INTO v_has_delete;

    IF v_has_delete THEN
        RAISE EXCEPTION 'FAIL: authenticated should NOT have DELETE privilege on xp_log';
    END IF;

    RAISE NOTICE 'PASS: authenticated has NO DELETE privilege on xp_log';
END $$;

-- TEST S5: Verify xp_log has CHECK constraint xp_change > 0
DO $$
DECLARE
    v_constraint_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE table_schema = 'public'
          AND table_name = 'xp_log'
          AND constraint_name = 'xp_change_must_be_positive'
    ) INTO v_constraint_exists;

    IF NOT v_constraint_exists THEN
        RAISE EXCEPTION 'FAIL: CHECK constraint xp_change_must_be_positive does not exist on xp_log';
    END IF;

    RAISE NOTICE 'PASS: CHECK constraint xp_change_must_be_positive exists on xp_log';
END $$;

-- TEST S6: Verify award_xp() is NOT executable by authenticated
DO $$
DECLARE
    v_has_execute BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.routine_privileges
        WHERE routine_schema = 'public'
          AND routine_name = 'award_xp'
          AND grantee = 'authenticated'
          AND privilege_type = 'EXECUTE'
    ) INTO v_has_execute;

    IF v_has_execute THEN
        RAISE EXCEPTION 'FAIL: authenticated should NOT have EXECUTE privilege on award_xp()';
    END IF;

    RAISE NOTICE 'PASS: authenticated has NO EXECUTE privilege on award_xp()';
END $$;

-- TEST S7: Verify award_xp() IS executable by service_role
DO $$
DECLARE
    v_has_execute BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.routine_privileges
        WHERE routine_schema = 'public'
          AND routine_name = 'award_xp'
          AND grantee = 'service_role'
          AND privilege_type = 'EXECUTE'
    ) INTO v_has_execute;

    IF NOT v_has_execute THEN
        RAISE EXCEPTION 'FAIL: service_role should have EXECUTE privilege on award_xp()';
    END IF;

    RAISE NOTICE 'PASS: service_role has EXECUTE privilege on award_xp()';
END $$;

-- ============================================================================
-- SECTION 2: EXECUTABLE SECURITY ATTACK & PERMISSION TESTS
-- ============================================================================

DO $$
DECLARE
    v_user_1 UUID := 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';
    v_user_2 UUID := 'bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb';
    v_initial_xp INTEGER;
    v_current_xp INTEGER;
    v_log_count INTEGER;
    v_updated_count INTEGER;
BEGIN
    RAISE NOTICE '=== SETUP: Creating test auth.users first ===';

    -- Create test users in auth.users (Supabase-managed table)
    -- Minimum required fields: id, email, encrypted_password
    INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
    VALUES
        (v_user_1, 'xp-test-user-1@example.com', 'dummy-hash-1', NOW(), NOW(), NOW()),
        (v_user_2, 'xp-test-user-2@example.com', 'dummy-hash-2', NOW(), NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    RAISE NOTICE '=== SETUP: Creating test public.users rows ===';

    -- Create test users in public.users (referenced by auth.users via FK)
    INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
    VALUES
        (v_user_1, 'XP Test User 1', 'E', 0, NOW(), NOW()),
        (v_user_2, 'XP Test User 2', 'E', 50, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    -- ========================================================================
    -- TEST A1: Direct total_xp manipulation blocked
    -- ========================================================================

    RAISE NOTICE '=== TEST A1: Blocked UPDATE (Authenticated attempting to update total_xp) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.users SET total_xp = 999999 WHERE id = v_user_1;
        RAISE EXCEPTION 'FAIL: total_xp update succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Permission denied (column UPDATE privilege prevents total_xp update)';
    END;

    RESET ROLE;

    -- ========================================================================
    -- TEST A2: Direct xp_log insertion blocked
    -- ========================================================================

    RAISE NOTICE '=== TEST A2: Blocked INSERT (Authenticated attempting to insert xp_log) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        INSERT INTO public.xp_log (user_id, xp_change, reason)
        VALUES (v_user_1, 100, 'fake reward');
        RAISE EXCEPTION 'FAIL: xp_log insert succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege OR check_violation OR invalid_row_security_violation THEN
        RAISE NOTICE 'PASS: Permission denied (no INSERT privilege on xp_log)';
    END;

    RESET ROLE;

    -- ========================================================================
    -- TEST A3: Negative XP blocked by constraint
    -- ========================================================================

    RAISE NOTICE '=== TEST A3: Blocked CONSTRAINT (Attempting to insert negative XP) ===';
    -- Even as postgres/backend, negative XP should be rejected by CHECK constraint
    BEGIN
        INSERT INTO public.xp_log (user_id, xp_change, reason)
        VALUES (v_user_1, -100, 'fake penalty');
        RAISE EXCEPTION 'FAIL: negative XP insert succeeded unexpectedly';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: Constraint rejected negative XP (xp_change > 0)';
    END;

    -- ========================================================================
    -- TEST A4: Zero XP blocked by constraint
    -- ========================================================================

    RAISE NOTICE '=== TEST A4: Blocked CONSTRAINT (Attempting to insert zero XP) ===';
    -- Zero XP should be rejected by CHECK constraint
    BEGIN
        INSERT INTO public.xp_log (user_id, xp_change, reason)
        VALUES (v_user_1, 0, 'fake zero award');
        RAISE EXCEPTION 'FAIL: zero XP insert succeeded unexpectedly';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: Constraint rejected zero XP (xp_change > 0)';
    END;

    -- ========================================================================
    -- TEST A5: Authenticated cannot call award_xp() directly
    -- ========================================================================

    RAISE NOTICE '=== TEST A5: Blocked EXECUTE (Authenticated attempting to call award_xp) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        SELECT award_xp(v_user_1, 100, 'self award');
        RAISE EXCEPTION 'FAIL: award_xp call succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Permission denied (no EXECUTE privilege on award_xp)';
    END;

    RESET ROLE;

    -- ========================================================================
    -- TEST A6: Service role can award XP successfully
    -- ========================================================================

    RAISE NOTICE '=== TEST A6: Allowed XP Award (Service role awarding XP) ===';

    -- Record initial XP
    SELECT total_xp INTO v_initial_xp FROM public.users WHERE id = v_user_1;

    -- Switch to service_role to award XP through secure function
    SET ROLE service_role;

    -- Award XP through secure function as service_role
    SELECT award_xp(v_user_1, 100, 'Task completed');

    -- Check updated XP
    SELECT total_xp INTO v_current_xp FROM public.users WHERE id = v_user_1;

    IF v_current_xp = v_initial_xp + 100 THEN
        RAISE NOTICE 'PASS: Service role successfully awarded 100 XP (% -> %)', v_initial_xp, v_current_xp;
    ELSE
        RAISE EXCEPTION 'FAIL: XP not updated correctly (% -> %, expected +100)', v_initial_xp, v_current_xp;
    END IF;

    -- Return to postgres for remaining tests
    SET ROLE postgres;

    -- ========================================================================
    -- TEST A7: XP accounting consistency (ledger matches total_xp)
    -- ========================================================================

    RAISE NOTICE '=== TEST A7: Consistency Check (XP ledger matches total_xp) ===';

    DECLARE
        v_total_xp_current INTEGER;
        v_xp_log_sum INTEGER;
    BEGIN
        -- Get current total_xp for test user
        SELECT total_xp INTO v_total_xp_current FROM public.users WHERE id = v_user_1;

        -- Get sum of all xp_change entries for test user
        SELECT COALESCE(SUM(xp_change), 0) INTO v_xp_log_sum FROM public.xp_log WHERE user_id = v_user_1;

        -- Verify they match
        IF v_total_xp_current = v_xp_log_sum THEN
            RAISE NOTICE 'PASS: users.total_xp (%) equals SUM(xp_log.xp_change) (%)', v_total_xp_current, v_xp_log_sum;
        ELSE
            RAISE EXCEPTION 'FAIL: XP mismatch - total_xp=% but xp_log_sum=% (should be equal)', v_total_xp_current, v_xp_log_sum;
        END IF;

        -- Also verify the expected amount is in the ledger
        IF v_xp_log_sum >= 100 THEN
            RAISE NOTICE 'PASS: XP log contains expected award amount (sum=%)', v_xp_log_sum;
        ELSE
            RAISE EXCEPTION 'FAIL: XP log sum (%) is less than expected award (100)', v_xp_log_sum;
        END IF;
    END;

    -- ========================================================================
    -- TEST A8: Cannot award XP to arbitrary users through authenticated
    -- ========================================================================

    RAISE NOTICE '=== TEST A8: Blocked (Authenticated attempting to award XP to another user) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        SELECT award_xp(v_user_2, 100, 'hacker attack');
        RAISE EXCEPTION 'FAIL: award_xp for another user succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Permission denied (no EXECUTE privilege on award_xp)';
    END;

    RESET ROLE;

    -- ========================================================================
    -- CLEANUP & TEARDOWN
    -- ========================================================================

    RAISE NOTICE '=== CLEANUP: Removing test fixtures ===';
    PERFORM set_config('request.jwt.claim.sub', '', true);

    -- Delete from public.users first (FK child)
    DELETE FROM public.users WHERE id IN (v_user_1, v_user_2);

    -- Delete from auth.users second (FK parent)
    DELETE FROM auth.users WHERE id IN (v_user_1, v_user_2);

    RAISE NOTICE '=== ALL XP SECURITY TESTS PASSED SUCCESSFULLY ===';
END $$;
