-- Migration: Enhance profile creation trigger with improved safety and documentation
-- Purpose: Ensure profile creation is database-driven and idempotent
-- Date: 2026-10-03

-- This migration improves the handle_new_user() trigger to:
-- 1. Add explicit search_path for security
-- 2. Remove broad exception handling to expose real errors
-- 3. Ensure the trigger is idempotent via ON CONFLICT
-- 4. Document the expected behavior

-- CRITICAL: This trigger MUST NOT silently swallow profile creation failures.
-- If public.users insertion fails, the auth.users INSERT transaction MUST fail.
-- This maintains the single source of truth: auth.users ↔ public.users (1:1).

-- Recreate the function with strict error propagation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_name TEXT;
BEGIN
    -- Extract name from auth metadata with fallback
    v_name := COALESCE(NEW.raw_user_meta_data->>'name', 'Studier');

    -- Ensure name is not empty
    IF v_name IS NULL OR btrim(v_name) = '' THEN
        v_name := 'Studier';
    END IF;

    -- Insert profile for new auth user
    -- ON CONFLICT (id) DO NOTHING ensures idempotency if this trigger somehow fires twice.
    -- Any other error (permission, constraint, schema) will propagate and fail the transaction.
    INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
    VALUES (
        NEW.id,
        v_name,
        'E',
        0,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;

    -- Return the auth user unchanged
    RETURN NEW;
END;
$$;

-- Ensure the trigger exists and is set up correctly
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Verify function ownership and permissions
-- The function must be owned by a role with sufficient privileges to INSERT into public.users.
-- SECURITY DEFINER allows the function to run with the owner's privileges.
-- Owner verification: SELECT proowner, pg_get_userbyid(proowner) FROM pg_proc WHERE proname = 'handle_new_user';
-- Expected: Owner should be 'postgres' or the role that created the migration.
