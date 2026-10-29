'use client';

import { AlertTriangle } from 'lucide-react';
import { useAuth } from '@/lib/auth-context';

/**
 * Shown when NEXT_PUBLIC_SUPABASE_* env vars are missing, so a fresh clone
 * explains itself instead of failing mysteriously.
 */
export function ConfigBanner() {
  const { configured } = useAuth();
  if (configured) return null;

  return (
    <div
      role="alert"
      className="mx-auto mb-6 flex w-full max-w-6xl items-start gap-3 rounded-xl border border-yellow-500/40 bg-yellow-500/10 px-4 py-3 text-sm text-yellow-200"
    >
      <AlertTriangle className="mt-0.5 h-5 w-5 shrink-0" aria-hidden />
      <p>
        <strong className="font-semibold">Supabase is not configured.</strong>{' '}
        Copy <code className="rounded bg-black/40 px-1">web/.env.example</code>{' '}
        to <code className="rounded bg-black/40 px-1">web/.env.local</code>, add
        your project URL and anon key, apply the migrations in{' '}
        <code className="rounded bg-black/40 px-1">supabase/migrations/</code>,
        then restart the dev server.
      </p>
    </div>
  );
}

export default ConfigBanner;
