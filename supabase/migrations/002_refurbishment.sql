-- JEE Solo Leveling — Migration 002: refurbishment
-- Apply AFTER 001_init_schema.sql (Supabase Dashboard → SQL Editor → Run).
--
-- What this fixes:
--  1. New sign-ups never got a public.users row → dashboard broke forever.
--     A trigger now creates the profile row automatically.
--  2. The leaderboard query could only ever return the current user
--     (RLS allowed reading only your own profile). A safe leaderboard
--     view exposes just id/name/xp/rank/streak to authenticated users.
--  3. Players could update their own total_xp / rank / ai_verdict from
--     the browser console. Column-level grants now lock those down.
--  4. XP values on self-created tasks were unlimited. Capped at 500
--     (keep in sync with MAX_TASK_XP in web/src/lib/utils.ts).
--  5. award_xp() never recomputed rank and there was no streak. It now
--     maintains both. Rank thresholds must match RANK_THRESHOLDS in
--     web/src/lib/utils.ts.
--  6. Proof photos need private storage: creates the `proofs` bucket
--     with per-player folder policies.

-- ------------------------------------------------------------------
-- 1. New columns: streak tracking + submission notes
-- ------------------------------------------------------------------
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS current_streak INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_active_date DATE;

ALTER TABLE public.submissions
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS ai_notes TEXT;

-- ------------------------------------------------------------------
-- 2. Cap task XP (existing >0 check from 001 stays; this tightens it)
-- ------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'tasks_xp_value_range'
    ) THEN
        ALTER TABLE public.tasks
            ADD CONSTRAINT tasks_xp_value_range
            CHECK (xp_value >= 1 AND xp_value <= 500);
    END IF;
END $$;

-- ------------------------------------------------------------------
-- 3. Auto-create a profile row for every new auth user
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.users (id, name)
    VALUES (
        NEW.id,
        COALESCE(
            NULLIF(btrim(NEW.raw_user_meta_data ->> 'name'), ''),
            NULLIF(split_part(COALESCE(NEW.email, ''), '@', 1), ''),
            'Player'
        )
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Backfill profiles for auth users created before this trigger existed.
INSERT INTO public.users (id, name)
SELECT
    au.id,
    COALESCE(
        NULLIF(btrim(au.raw_user_meta_data ->> 'name'), ''),
        NULLIF(split_part(COALESCE(au.email, ''), '@', 1), ''),
        'Player'
    )
FROM auth.users au
ON CONFLICT (id) DO NOTHING;

-- Client-side fallback (lib/profile.ts) may insert its own row if the
-- trigger was applied late.
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
CREATE POLICY "Users can insert their own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- ------------------------------------------------------------------
-- 4. Anti-cheat column locks
-- RLS decides WHICH rows you can touch; these grants decide WHICH
-- columns. XP/rank/streak may only change via award_xp() (service role),
-- verdicts only via the verification route (service role).
-- ------------------------------------------------------------------
REVOKE UPDATE ON public.users FROM authenticated;
GRANT UPDATE (name) ON public.users TO authenticated;

DROP POLICY IF EXISTS "Users can update submissions for their tasks" ON public.submissions;
REVOKE UPDATE ON public.submissions FROM authenticated;

REVOKE UPDATE ON public.tasks FROM authenticated;
GRANT UPDATE (title, subject, xp_value) ON public.tasks TO authenticated;

-- ------------------------------------------------------------------
-- 5. award_xp v2: ledger + total + rank + streak, service-role only
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.award_xp(
    p_user_id UUID,
    p_xp_change INTEGER,
    p_reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_new_xp INTEGER;
    v_last DATE;
    v_streak INTEGER;
    v_rank TEXT;
BEGIN
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'User ID is required';
    END IF;

    IF p_xp_change IS NULL OR p_xp_change = 0 THEN
        RAISE EXCEPTION 'XP change must be a non-zero integer';
    END IF;

    IF p_reason IS NULL OR btrim(p_reason) = '' THEN
        RAISE EXCEPTION 'XP award reason is required';
    END IF;

    IF auth.uid() IS NOT NULL AND p_user_id <> auth.uid() THEN
        RAISE EXCEPTION 'Users may only award XP to themselves';
    END IF;

    INSERT INTO public.xp_log (user_id, xp_change, reason, created_at)
    VALUES (p_user_id, p_xp_change, p_reason, NOW());

    SELECT last_active_date, current_streak
      INTO v_last, v_streak
      FROM public.users
     WHERE id = p_user_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found for user %', p_user_id;
    END IF;

    UPDATE public.users
       SET total_xp = GREATEST(0, total_xp + p_xp_change),
           updated_at = NOW()
     WHERE id = p_user_id
     RETURNING total_xp INTO v_new_xp;

    -- Rank thresholds — keep in sync with RANK_THRESHOLDS in utils.ts
    v_rank := CASE
        WHEN v_new_xp >= 25000 THEN 'S'
        WHEN v_new_xp >= 10000 THEN 'A'
        WHEN v_new_xp >= 5000  THEN 'B'
        WHEN v_new_xp >= 2500  THEN 'C'
        WHEN v_new_xp >= 1000  THEN 'D'
        ELSE 'E'
    END;

    -- Streak only advances on positive XP (i.e. actually studying).
    IF p_xp_change > 0 THEN
        v_streak := CASE
            WHEN v_last = CURRENT_DATE THEN COALESCE(v_streak, 1)
            WHEN v_last = CURRENT_DATE - 1 THEN COALESCE(v_streak, 0) + 1
            ELSE 1
        END;
        UPDATE public.users
           SET rank = v_rank,
               current_streak = v_streak,
               last_active_date = CURRENT_DATE
         WHERE id = p_user_id;
    ELSE
        UPDATE public.users SET rank = v_rank WHERE id = p_user_id;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.award_xp FROM PUBLIC;
REVOKE ALL ON FUNCTION public.award_xp FROM authenticated;
REVOKE ALL ON FUNCTION public.award_xp FROM anon;
GRANT EXECUTE ON FUNCTION public.award_xp TO service_role;

-- ------------------------------------------------------------------
-- 6. Leaderboard view (safe columns only, readable by all players)
-- Views run with the owner's rights by default, bypassing the
-- own-row-only policy on public.users without exposing anything else.
-- ------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_users_total_xp ON public.users (total_xp DESC);

CREATE OR REPLACE VIEW public.leaderboard AS
SELECT id, name, total_xp, rank, current_streak
FROM public.users;

REVOKE ALL ON public.leaderboard FROM PUBLIC, anon;
GRANT SELECT ON public.leaderboard TO authenticated;

-- ------------------------------------------------------------------
-- 7. Private `proofs` storage bucket + per-player folder policies
-- Object paths look like: <user_id>/<task_id>/<timestamp>-<file>
-- ------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('proofs', 'proofs', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Players can upload their own proofs" ON storage.objects;
CREATE POLICY "Players can upload their own proofs" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'proofs'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Players can view their own proofs" ON storage.objects;
CREATE POLICY "Players can view their own proofs" ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'proofs'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Players can delete their own proofs" ON storage.objects;
CREATE POLICY "Players can delete their own proofs" ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'proofs'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
