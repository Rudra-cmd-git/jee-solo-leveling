# Claude Code Project Handoff

Read this file at the start of each session, then verify important status against the repository before making changes. Keep the **Current Status** section up to date when meaningful work is completed. Never put passwords, API keys, tokens, or other secrets in this file or commit them.

## Project

JEE Solo Leveling is planned as a gamified JEE study tracker with tasks, proof submissions, XP, ranks, and a leaderboard.

Planned stack:
- Next.js and React for the application
- Supabase for database and authentication
- Claude API for image/proof verification
- Vercel for hosting

## Current Status

Updated: 2026-10-03

- The Supabase project is set up and the migration has been applied (as evidenced by the modified migration file).
- The runnable Next.js app is in `web/`; npm commands should be run from that directory.
- Local environment variables are kept in `web/.env.local`; never publish their values. The current verification route calls VisionSter and does not use a Claude API key.
- `npm run build` succeeds from `web/`; the homepage (`/`) now displays the study tracker dashboard with pending tasks, recent submissions, leaderboard, and actions to create tasks and submit proof.
- Authentication is implemented via Supabase (sign-in, sign-up, session management).
- Task creation and submission flows are fully functional:
  * Users can create tasks with title, subject, and XP value.
  * Users can submit proof (image URL) for a task, which triggers:
    1. Creation of a submission record with status 'pending'.
    2. Verification using the VisionSter API through the server-side route `/api/verify-submission`; proof image URLs are sent to that provider.
    3. Update of the submission with the verification verdict (approved/rejected/pending).
    4. The client currently calls `award_xp()` when verification is approved, but the function is restricted to `service_role`; end-to-end XP awarding needs a trusted server-side path and validation.
- The `public.award_xp()` function is secured so that authenticated users can only award XP to themselves, and execute permission is restricted to the trusted `service_role` path.
- The leaderboard page (`/profile`) displays user rankings, XP, and statistics.
- UI components (buttons, inputs, modals) have been updated with a consistent design.

## Suggested Next Steps

1. **Review verification-provider data handling**: Proof image URLs are sent to VisionSter; assess its privacy and reliability before production.
2. **Move XP awarding server-side**: Call the restricted `award_xp()` function from a trusted server-side path and test its authorization.
3. **Test end-to-end flow**: Create a task, submit a valid study image, and verify the verdict and XP update.
4. **Add verification retry**: Allow users to retry verification for a submission that failed or was rejected.
5. **Implement loading states**: Enhance UI with more granular loading states during verification.
6. **Write tests**: Add unit and integration tests for critical functions (e.g. verification route, XP awarding).
7. **Prepare for deployment**: Configure Vercel environment variables and validate the production build.
8. **Monitor usage**: Add logging for verification requests and responses to monitor reliability and costs.

## Working Conventions

- Inspect existing files and preserve user changes; make the smallest focused change that fits the repository.
- Protect Supabase Row Level Security. Never put the service-role/secret key in a `NEXT_PUBLIC_` variable or browser code.
- Prefer server-side handling for privileged operations, including XP awards and external verification calls. Keep private API credentials server-only.
- Run the narrowest relevant checks after changes; app scripts are in `web/`.