import type { User } from '@supabase/supabase-js';
import { supabase } from './supabase';
import type { Profile } from './types';

/**
 * Fetch the public.users profile for `user`, creating it if missing.
 *
 * Migration 002 adds a trigger that creates this row on sign-up, but this
 * fallback keeps accounts created before that trigger (or before it is
 * applied) working. Requires the "insert own profile" RLS policy from 002;
 * if that is missing too, this returns null and pages show an empty state
 * rather than crashing.
 */
export async function ensureProfile(user: User): Promise<Profile | null> {
  const { data, error } = await supabase
    .from('users')
    .select('*')
    .eq('id', user.id)
    .maybeSingle();

  if (!error && data) {
    return data as Profile;
  }

  const fallbackName =
    (typeof user.user_metadata?.name === 'string' &&
    user.user_metadata.name.trim()
      ? user.user_metadata.name.trim()
      : null) ??
    user.email?.split('@')[0] ??
    'Player';

  const { data: inserted, error: insertError } = await supabase
    .from('users')
    .insert({ id: user.id, name: fallbackName })
    .select('*')
    .single();

  if (insertError) {
    console.error('Could not create profile row:', insertError.message);
    return null;
  }

  return inserted as Profile;
}
