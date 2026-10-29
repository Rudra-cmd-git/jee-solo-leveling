'use client';

import * as React from 'react';
import type { User } from '@supabase/supabase-js';
import { supabase, isSupabaseConfigured } from '@/lib/supabase';
import { onAuthStateChange } from '@/lib/auth';

interface AuthContextProps {
  user: User | null;
  loading: boolean;
  /** False when the Supabase env vars are missing (UI shows a setup banner). */
  configured: boolean;
}

const AuthContext = React.createContext<AuthContextProps | undefined>(
  undefined,
);

export function useAuth() {
  const context = React.useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = React.useState<User | null>(null);
  const [loading, setLoading] = React.useState<boolean>(true);

  React.useEffect(() => {
    let isMounted = true;

    if (!isSupabaseConfigured) {
      // No backend to talk to; resolve immediately so pages can render
      // their "not configured" state instead of spinning forever.
      const timer = window.setTimeout(() => {
        if (isMounted) setLoading(false);
      }, 0);
      return () => {
        isMounted = false;
        window.clearTimeout(timer);
      };
    }

    // getSession reads the locally stored session (no network round-trip
    // when there is no session), unlike getUser which always calls the API.
    supabase.auth
      .getSession()
      .then(({ data }) => {
        if (!isMounted) return;
        setUser(data.session?.user ?? null);
        setLoading(false);
      })
      .catch(() => {
        if (isMounted) setLoading(false);
      });

    const subscription = onAuthStateChange((nextUser) => {
      if (!isMounted) return;
      setUser(nextUser);
      setLoading(false);
    });

    return () => {
      isMounted = false;
      subscription.data.subscription.unsubscribe();
    };
  }, []);

  // Always render children: pages handle their own loading/redirect states.
  // (Previously this returned a bare "Loading..." div for the whole app.)
  return (
    <AuthContext.Provider
      value={{ user, loading, configured: isSupabaseConfigured }}
    >
      {children}
    </AuthContext.Provider>
  );
}
