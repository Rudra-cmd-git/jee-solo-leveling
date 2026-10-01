'use client';

import * as React from 'react';
import { User } from '@supabase/supabase-js';
import { supabase } from '@/lib/supabase';
import { onAuthStateChange } from '@/lib/auth';

interface AuthContextProps {
  user: User | null;
  loading: boolean;
}

const AuthContext = React.createContext<AuthContextProps | undefined>(undefined);

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

    async function loadUser() {
      const { data: { user: initialUser } } = await supabase.auth.getUser();
      if (!isMounted) return;
      setUser(initialUser);
      setLoading(false);
    }

    void loadUser();

    const subscription = onAuthStateChange((user) => {
      if (!isMounted) return;
      setUser(user);
      setLoading(false);
    });

    return () => {
      isMounted = false;
      subscription.data.subscription.unsubscribe();
    };
  }, []);

  if (loading) {
    return <div>Loading...</div>;
  }

  return (
    <AuthContext.Provider value={{ user, loading }}>
      {children}
    </AuthContext.Provider>
  );
}