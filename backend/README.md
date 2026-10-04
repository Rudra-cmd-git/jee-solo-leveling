# Backend — Database & API Layer

This directory contains all backend-specific changes for Priority 0: User Profile Creation Foundation.

## What Changed?

The user profile creation system was repaired to eliminate a race condition:

**Before**: Frontend manually created profiles (redundant with database trigger)  
**After**: Database trigger handles profile creation atomically

## For Frontend Developers

✅ **Good news**: The frontend change is minimal and non-breaking.

**What changed in `web/src/lib/auth.ts`:**
- Removed redundant manual profile creation code (18 lines)
- Kept name in auth metadata (required for trigger to extract it)
- No changes to sign-in, sign-up UI, or profile pages
- Build passes with no errors

**What you need to know:**
- Signup still works exactly the same
- Profile pages will load as before (profiles are auto-created by database)
- No new dependencies or breaking changes
- No impact on your frontend code or workflows

## Database Migrations

Located in `supabase/migrations/`:

1. **`001_init_schema.sql`** — Initial schema setup, RLS policies, secure XP award function
2. **`002_enhance_profile_creation_trigger.sql`** — Profile creation trigger with explicit search_path
3. **`003_backfill_missing_profiles.sql`** — Backfills missing user profiles
4. **`004_lock_down_users_rls.sql`** — Restricted RLS UPDATE policy
5. **`005_enforce_users_column_security.sql`** — PostgreSQL column-level privileges for public.users
6. **`006_lock_down_tasks_rls.sql`** — Restricted RLS policies & column privileges for public.tasks
7. **`007_restrict_tasks_insert.sql`** — Revokes INSERT privilege on public.tasks from authenticated role

**To deploy**: Apply migrations in `supabase/migrations/` in order.

## Testing

Located in `tests/`:

- **`profile_creation_tests.sql`** — Profile creation trigger test suite
- **`users_column_security_tests.sql`** — Executable column security & RLS test suite
- **`users_rls_security_tests.sql`** — Structural verification & data integrity test suite
- **`tasks_security_tests.sql`** — Executable tasks RLS & column security test suite

## Key Points for Frontend

| Aspect | Status | Notes |
|--------|--------|-------|
| Frontend code change | ✅ Minimal | Only removed redundant code |
| Breaking changes | ❌ None | Everything works as before |
| New dependencies | ❌ None | No changes to package.json |
| UI changes | ❌ None | Sign-up/profile pages unchanged |
| Build status | ✅ Passes | No errors or warnings |
| TypeScript | ✅ Clean | All types correct |

## Deployment Order

1. **Deploy database migrations first** (apply 002, then 003)
2. **Then deploy frontend code** (the auth.ts changes)
3. **Run test suite** to verify everything works

## Questions?

- Database schema questions? See `supabase/migrations/` or run the test suite in `tests/`.

---

**Status**: ✅ Ready for production  
**Commit**: `dd2abb2`  
**Date**: 2026-10-03
