-- JEE Solo Leveling System Database Schema
-- Migration: Initial schema setup

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    rank TEXT DEFAULT 'E' CHECK (rank IN ('E', 'D', 'C', 'B', 'A', 'S')),
    total_xp INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tasks table
CREATE TABLE IF NOT EXISTS public.tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    subject TEXT NOT NULL,
    xp_value INTEGER NOT NULL CHECK (xp_value > 0),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Submissions table (proof submissions)
CREATE TABLE IF NOT EXISTS public.submissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    photo_url TEXT NOT NULL,
    ai_verdict TEXT CHECK (ai_verdict IN ('approved', 'rejected', 'pending')),
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    verified_at TIMESTAMP WITH TIME ZONE
);

-- XP Ledger table
CREATE TABLE IF NOT EXISTS public.xp_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    xp_change INTEGER NOT NULL,
    reason TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON public.tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks(status);
CREATE INDEX IF NOT EXISTS idx_submissions_task_id ON public.submissions(task_id);
CREATE INDEX IF NOT EXISTS idx_submissions_ai_verdict ON public.submissions(ai_verdict);
CREATE INDEX IF NOT EXISTS idx_xp_log_user_id ON public.xp_log(user_id);
CREATE INDEX IF NOT EXISTS idx_xp_log_created_at ON public.xp_log(created_at);

-- Enable Row Level Security
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.xp_log ENABLE ROW LEVEL SECURITY;

-- RLS Policies for users
DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
CREATE POLICY "Users can view their own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
CREATE POLICY "Users can insert their own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
CREATE POLICY "Users can update their own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

-- Keep a profile row in sync with each new auth user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, name, rank, total_xp, created_at, updated_at)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', 'Studier'),
        'E',
        0,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- RLS Policies for tasks
DROP POLICY IF EXISTS "Users can view their own tasks" ON public.tasks;
CREATE POLICY "Users can view their own tasks" ON public.tasks
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own tasks" ON public.tasks;
CREATE POLICY "Users can insert their own tasks" ON public.tasks
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own tasks" ON public.tasks;
CREATE POLICY "Users can update their own tasks" ON public.tasks
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own tasks" ON public.tasks;
CREATE POLICY "Users can delete their own tasks" ON public.tasks
    FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for submissions
DROP POLICY IF EXISTS "Users can view submissions for their tasks" ON public.submissions;
CREATE POLICY "Users can view submissions for their tasks" ON public.submissions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.tasks WHERE public.tasks.id = task_id AND public.tasks.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can insert submissions for their tasks" ON public.submissions;
CREATE POLICY "Users can insert submissions for their tasks" ON public.submissions
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.tasks WHERE public.tasks.id = task_id AND public.tasks.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can update submissions for their tasks" ON public.submissions;
CREATE POLICY "Users can update submissions for their tasks" ON public.submissions
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.tasks WHERE public.tasks.id = task_id AND public.tasks.user_id = auth.uid()
        )
    );

-- RLS Policies for xp_log
DROP POLICY IF EXISTS "Users can view their own XP log" ON public.xp_log;
CREATE POLICY "Users can view their own XP log" ON public.xp_log
    FOR SELECT USING (auth.uid() = user_id);

-- Prevent direct XP manipulation - only trusted server-side callers should award XP
-- Authenticated users can only award XP to themselves; service_role remains available
-- for trusted backend workflows such as Edge Functions or server actions.
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
BEGIN
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'User ID is required';
    END IF;

    IF p_reason IS NULL OR btrim(p_reason) = '' THEN
        RAISE EXCEPTION 'XP award reason is required';
    END IF;

    IF auth.uid() IS NOT NULL AND p_user_id <> auth.uid() THEN
        RAISE EXCEPTION 'Users may only award XP to themselves';
    END IF;

    INSERT INTO public.xp_log (user_id, xp_change, reason, created_at)
    VALUES (p_user_id, p_xp_change, p_reason, NOW());

    UPDATE public.users
    SET total_xp = total_xp + p_xp_change,
        updated_at = NOW()
    WHERE id = p_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.award_xp FROM PUBLIC;
REVOKE ALL ON FUNCTION public.award_xp FROM authenticated;
REVOKE ALL ON FUNCTION public.award_xp FROM anon;
GRANT EXECUTE ON FUNCTION public.award_xp TO service_role;

-- Create a policy that prevents direct updates to XP log (only inserts via function)
DROP POLICY IF EXISTS "Prevent direct XP log updates" ON public.xp_log;
CREATE POLICY "Prevent direct XP log updates" ON public.xp_log
    FOR UPDATE USING (false);

DROP POLICY IF EXISTS "Prevent direct XP log deletions" ON public.xp_log;
CREATE POLICY "Prevent direct XP log deletions" ON public.xp_log
    FOR DELETE USING (false);

-- Updated_at trigger for users table
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_tasks_updated_at ON public.tasks;
CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON public.tasks
    FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();