# Deploying JEE Solo Leveling to Vercel

The Next.js app lives in `web/`, so the one setting that matters is pointing
Vercel at that folder. Everything else is environment variables.

## 1. Database (Supabase) — do this first

In the Supabase SQL Editor, run in order:

1. `supabase/migrations/001_init_schema.sql`
2. `supabase/migrations/002_refurbishment.sql`

Both are idempotent (`IF NOT EXISTS` / `ON CONFLICT` guards), so re-running
is safe. See `SUPABASE_SETUP.md` for what each one does.

Also in Supabase Dashboard → **Authentication → URL Configuration**, set
**Site URL** to your production URL (e.g. `https://jee-solo-leveling.vercel.app`)
once you know it, and add it under **Redirect URLs**.

## 2. Import the repo into Vercel

1. [vercel.com](https://vercel.com) → **Add New… → Project** → import
   `Rudra-cmd-git/jee-solo-leveling`.
2. **Root Directory:** click *Edit* and select **`web`** ← important!
3. Framework preset: **Next.js** (auto-detected). Build/output settings:
   leave as defaults (`npm run build`, Next.js output).
4. Add the environment variables below **before** the first deploy
   (or add them after and redeploy).
5. Deploy.

## 3. Environment variables

| Name | Value | Notes |
| --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | `https://<project-ref>.supabase.co` | Supabase → Project Settings → API |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | anon / publishable key | Browser-safe; RLS protects data |
| `SUPABASE_SERVICE_ROLE_KEY` | service_role / secret key | **Server only.** Used solely by `/api/submissions/verify` to award XP. Never expose client-side. |
| `ANTHROPIC_API_KEY` | Anthropic API key | **Server only.** Enables Claude Vision proof verification. Without it, submissions stay `pending`. |
| `ANTHROPIC_MODEL` | *(optional)* | Defaults to `claude-sonnet-4-5` |

Apply them to **Production** (and Preview if you want PR previews to work
against the same database).

## 4. After the first deploy

- Open the site → **Create account** → sign in → create a quest →
  submit a proof photo. If both server keys are set, the System verifies
  the photo and awards XP within a few seconds.
- Update Supabase **Site URL** to the real Vercel domain (step 1).
- Note: on Supabase's free tier the project pauses after a period of
  inactivity; the first request after a pause may be slow, and you may
  need to restore it from the dashboard.

## 5. Local preview of a production build

```bash
cd web
npm run build
npm run start   # http://localhost:3000
```
