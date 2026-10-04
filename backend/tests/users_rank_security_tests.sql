-- TEST SUITE: Rank Server-Controlled Security Verification
-- Purpose: Verify that public.users.rank is completely server-controlled and cannot
--          be manipulated by authenticated clients, while trusted backend operations
--          retain full capability to manage rank.
-- File: backend/tests/users_rank_security_tests.sql
-- Run in Supabase SQL editor as postgres.

-- ============================================================================
-- SECTION 1: STRUCTURAL TESTS (Catalog Assertions)
-- ============================================================================

-- TEST S1: Verify RLS is enabled on public.users
SELECT
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'users' AND schemaname = 'public';

-- TEST S2: Verify RLS SELECT and UPDATE policies exist (not INSERT)
SELECT
    policyname,
    permissive,
    cmd as operation,
    roles,
    qual as using_expression
FROM pg_policies
WHERE tablename = 'users' AND schemaname = 'public'
ORDER BY cmd, policyname;

-- TEST S3: Verify authenticated has NO INSERT privilege on public.users
DO $$
DECLARE
    v_has_insert BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_privileges
        WHERE table_name = 'users'
          AND table_schema = 'public'
          AND grantee = 'authenticated'
          AND privilege_type = 'INSERT'
    ) INTO v_has_insert;

    IF v_has_insert THEN
        RAISE EXCEPTION 'FAIL: authenticated should NOT have INSERT privilege on public.users';
    END IF;

    RAISE NOTICE 'PASS: authenticated has NO INSERT privilege on public.users';
END $$;

-- TEST S4: Verify authenticated UPDATE privileges are ONLY on name column
DO $$
DECLARE
    v_update_columns TEXT[];
BEGIN
    SELECT ARRAY_AGG(column_name ORDER BY column_name)
    INTO v_update_columns
    FROM information_schema.column_privileges
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND grantee = 'authenticated'
      AND privilege_type = 'UPDATE';

    IF v_update_columns IS DISTINCT FROM ARRAY['name']::TEXT[] THEN
        RAISE EXCEPTION
            'FAIL: authenticated UPDATE privileges incorrect. Expected [name], actual: %',
            v_update_columns;
    END IF;

    RAISE NOTICE 'PASS: authenticated UPDATE privilege is restricted exactly to name column';
END $$;

-- TEST S5: Verify authenticated has NO UPDATE privilege on rank column
DO $$
DECLARE
    v_has_rank_update BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.column_privileges
        WHERE table_schema = 'public'
          AND table_name = 'users'
          AND column_name = 'rank'
          AND grantee = 'authenticated'
          AND privilege_type = 'UPDATE'
    ) INTO v_has_rank_update;

    IF v_has_rank_update THEN
        RAISE EXCEPTION 'FAIL: authenticated should NOT have UPDATE(rank) privilege';
    END IF;

    RAISE NOTICE 'PASS: authenticated has NO UPDATE privilege on rank column';
END $$;

-- TEST S6: Verify authenticated has NO UPDATE privilege on total_xp, id, created_at, updated_at
DO $$
DECLARE
    v_protected_columns TEXT[];
BEGIN
    SELECT ARRAY_AGG(column_name ORDER BY column_name)
    INTO v_protected_columns
    FROM information_schema.column_privileges
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND grantee = 'authenticated'
      AND privilege_type = 'UPDATE'
      AND column_name IN ('id', 'total_xp', 'rank', 'created_at', 'updated_at');

    IF v_protected_columns IS NOT NULL AND array_length(v_protected_columns, 1) > 0 THEN
        RAISE EXCEPTION
            'FAIL: authenticated should NOT have UPDATE on server-controlled columns. Found: %',
            v_protected_columns;
    END IF;

    RAISE NOTICE 'PASS: authenticated has NO UPDATE privilege on any server-controlled columns';
END $$;

-- TEST S7: Verify authenticated has SELECT privilege on public.users
DO $$
DECLARE
    v_has_select BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_privileges
        WHERE table_name = 'users'
          AND table_schema = 'public'
          AND grantee = 'authenticated'
          AND privilege_type = 'SELECT'
    ) INTO v_has_select;

    IF NOT v_has_select THEN
        RAISE EXCEPTION 'FAIL: authenticated should have SELECT privilege on public.users';
    END IF;

    RAISE NOTICE 'PASS: authenticated has SELECT privilege on public.users';
END $$;

-- ============================================================================
-- SECTION 2: EXECUTABLE SECURITY ATTACK & PERMISSION TESTS
-- ============================================================================

DO $$
DECLARE
    v_user_1 UUID := 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';
    v_user_2 UUID := 'bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb';
    v_read_count INTEGER;
    v_updated_count INTEGER;
BEGIN
    RAISE NOTICE '=== SETUP: Creating test users as postgres ===';

    -- Create test users directly as postgres
    INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
    VALUES
        (v_user_1, 'Rank Test User 1', 'E', 0, NOW(), NOW()),
        (v_user_2, 'Rank Test User 2', 'D', 100, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    -- ========================================================================
    -- TEST A1: Authenticated user cannot update own rank
    -- ========================================================================

    RAISE NOTICE '=== TEST A1: Blocked UPDATE (Authenticated attempting to update own rank) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.users SET rank = 'S' WHERE id = v_user_1;
        RAISE EXCEPTION 'FAIL: Rank update succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Permission denied (column UPDATE privilege prevents rank update)';
    END;

    RESET ROLE;

    -- ========================================================================
    -- TEST A2: Authenticated user cannot update another user's rank
    -- ========================================================================

    RAISE NOTICE '=== TEST A2: Blocked UPDATE (Authenticated attempting to update another user rank) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.users SET rank = 'S' WHERE id = v_user_2;
        RAISE EXCEPTION 'FAIL: Cross-user rank update succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Permission denied (column UPDATE privilege prevents rank update)';
    END;

    RESET ROLE;

    -- ========================================================================
    -- TEST A3: Authenticated user can still update own name
    -- ========================================================================

    RAISE NOTICE '=== TEST A3: Allowed UPDATE (Authenticated updating own name) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    UPDATE public.users SET name = 'Updated Name' WHERE id = v_user_1;

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count = 1 THEN
        RAISE NOTICE 'PASS: User can still update own name';
    ELSE
        RAISE EXCEPTION 'FAIL: Name update failed';
    END IF;

    RESET ROLE;

    -- ========================================================================
    -- TEST A4: Authenticated user cannot insert a profile with forged rank
    -- ========================================================================

    RAISE NOTICE '=== TEST A4: Blocked INSERT (Authenticated attempting to insert with rank) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', 'cccccccc-cccc-4ccc-cccc-cccccccccccc'::text, true);

    BEGIN
        INSERT INTO public.users (id, name, rank, total_xp)
        VALUES ('cccccccc-cccc-4ccc-cccc-cccccccccccc', 'Forged User', 'S', 999999);
        RAISE EXCEPTION 'FAIL: Profile insert with forged rank succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Permission denied (no INSERT privilege on public.users)';
    END;

    RESET ROLE;

    -- ========================================================================
    -- TEST A5: Authenticated user cannot modify total_xp (regression test)
    -- ========================================================================

    RAISE NOTICE '=== TEST A5: Blocked UPDATE (Authenticated attempting to update total_xp) ===';
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
    -- TEST A6: Authenticated user cannot modify id
    -- ========================================================================

    RAISE NOTICE '=== TEST A6: Blocked UPDATE (Authenticated attempting to update id) ===';
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claim.sub', v_user_1::text, true);

    BEGIN
        UPDATE public.users SET id = 'dddddddd-dddd-4ddd-dddd-dddddddddddd' WHERE id = v_user_1;
        RAISE EXCEPTION 'FAIL: id update succeeded unexpectedly';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASS: Permission denied (column UPDATE privilege prevents id update)';
    END;

    RESET ROLE;

    -- ========================================================================
    -- TEST T1: Trusted backend (postgres role) can update rank
    -- ========================================================================

    RAISE NOTICE '=== TEST T1: Allowed UPDATE (Trusted backend updating rank as postgres) ===';
    -- Already running as postgres (default after RESET ROLE)

    UPDATE public.users SET rank = 'A', total_xp = 500 WHERE id = v_user_1;

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count = 1 THEN
        RAISE NOTICE 'PASS: Trusted backend can update rank and total_xp';
    ELSE
        RAISE EXCEPTION 'FAIL: Trusted backend rank update failed';
    END IF;

    -- ========================================================================
    -- CLEANUP & TEARDOWN
    -- ========================================================================

    RAISE NOTICE '=== CLEANUP: Removing test fixtures as postgres ===';
    PERFORM set_config('request.jwt.claim.sub', '', true);

    DELETE FROM public.users WHERE id IN (v_user_1, v_user_2);

    RAISE NOTICE '=== ALL RANK SECURITY TESTS PASSED SUCCESSFULLY ===';
END $$;
