-- Migration: Enhance profile creation trigger with improved safety and documentation
-- Purpose: Ensure profile creation is database-driven and idempotent
-- Date: 2026-10-03

-- This migration improves the handle_new_user() trigger to:
-- 1. Add explicit search_path for security
-- 2. Add error handling
-- 3. Ensure the trigger is idempotent
-- 4. Document the expected behavior

-- Recreate the function with improved safety
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
    -- ON CONFLICT handles the case where the profile row already exists
    -- (e.g., if this trigger somehow fires multiple times)
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
EXCEPTION WHEN OTHERS THEN
    -- Log the error but don't fail the auth user creation
    -- The auth.users row has already been inserted at this point
    RAISE WARNING 'Failed to create user profile for auth user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

-- Ensure the trigger exists and is set up correctly
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Verify that the trigger is in place
-- (This is a safety check and can be removed in production)
-- SELECT trigger_name, event_manipulation, event_object_table
-- FROM information_schema.triggers
-- WHERE trigger_name = 'on_auth_user_created';
