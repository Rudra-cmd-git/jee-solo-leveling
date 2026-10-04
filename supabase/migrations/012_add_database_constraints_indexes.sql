-- Migration: Add database constraints and indexes
-- Purpose: Improve data integrity and query performance
--          with justified constraints and indexes based on
--          actual application query patterns and business rules.
-- Date: 2026-10-04

-- ============================================================================
-- PART 1: DATA-INTEGRITY CONSTRAINTS
-- ============================================================================

-- CONSTRAINT 1: users.total_xp must be non-negative
-- Rationale: XP should never be negative. This constraint ensures
--           the database rejects any attempt to set negative XP values.
-- Note: Migration 011 already constrains xp_change > 0, but this ensures
--       the accumulated total_xp column itself remains valid.
ALTER TABLE public.users
ADD CONSTRAINT total_xp_non_negative CHECK (total_xp >= 0);

-- CONSTRAINT 2: tasks.title must not be empty or whitespace-only
-- Rationale: A task without a meaningful title is not useful.
--           This constraint prevents users from creating tasks with empty titles.
-- Implementation: Use trim() to reject whitespace-only strings.
ALTER TABLE public.tasks
ADD CONSTRAINT title_not_empty CHECK (btrim(title) != '');

-- CONSTRAINT 3: tasks.subject must not be empty or whitespace-only
-- Rationale: Task subject is required metadata for study organization.
--           Similar to title, empty subjects provide no value.
ALTER TABLE public.tasks
ADD CONSTRAINT subject_not_empty CHECK (btrim(subject) != '');

-- CONSTRAINT 4: submissions.photo_url must not be empty or whitespace-only
-- Rationale: A submission proof image URL must be a valid non-empty string.
--           Whitespace-only URLs are meaningless and cannot be fetched.
ALTER TABLE public.submissions
ADD CONSTRAINT photo_url_not_empty CHECK (btrim(photo_url) != '');

-- CONSTRAINT 5: xp_log.reason must not be empty or whitespace-only
-- Rationale: XP award reason is audit/transparency metadata.
--           It should always explain why XP was awarded.
ALTER TABLE public.xp_log
ADD CONSTRAINT reason_not_empty CHECK (btrim(reason) != '');

-- ============================================================================
-- PART 2: PERFORMANCE INDEXES
-- ============================================================================

-- INDEX 1: xp_log(user_id, created_at) composite index
-- Rationale: Users frequently retrieve their XP history in chronological order.
--           A composite index on (user_id, created_at) supports this common query pattern:
--             SELECT * FROM xp_log WHERE user_id = ? ORDER BY created_at DESC
--           This is more efficient than separate indexes because:
--           - PostgreSQL can satisfy the WHERE clause and sort in a single index scan
--           - Supports RLS ownership checks on xp_log efficiently
-- Note: Individual idx_xp_log_user_id and idx_xp_log_created_at already exist
--       from migration 001. This composite index is complementary for combined queries.
CREATE INDEX IF NOT EXISTS idx_xp_log_user_id_created_at
ON public.xp_log(user_id, created_at DESC);

-- ============================================================================
-- MIGRATION SAFETY
-- ============================================================================

-- This migration uses:
-- - ADD CONSTRAINT with explicit column names for clarity
-- - CHECK constraints with business-logic validation (btrim)
-- - IF NOT EXISTS for the new index to avoid duplicate index errors
-- - All changes are additive; no existing constraints/indexes are removed
-- - Existing RLS policies remain unchanged
-- - Existing column privileges remain unchanged
-- - No schema redesign; only justified integrity and performance improvements

-- The constraints may cause issues if existing data violates them.
-- This migration assumes the existing application maintains the invariants
-- (e.g., total_xp is already non-negative, titles are non-empty).
-- If legacy data exists that violates these rules, a data cleanup step
-- would be required before applying this migration.
