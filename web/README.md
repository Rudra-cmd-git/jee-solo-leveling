# JEE Solo Leveling Web App

This folder contains the Next.js application. Run app commands from `web/`.

## Run locally

```bash
npm install
npm run dev
```

Open http://localhost:3000. Use `npm run build` for a production build and `npm run lint` for ESLint.

Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` in `.env.local` for Supabase client access. Keep secret/service-role keys server-side and never commit `.env.local`.

For a file-by-file directory map, see [`../FILE_GUIDE.md`](../FILE_GUIDE.md). The root [README](../README.md) describes the product and database setup.
