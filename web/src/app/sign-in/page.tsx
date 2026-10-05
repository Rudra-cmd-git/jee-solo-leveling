'use client';

import { useEffect, useState } from 'react';
import { LockKeyhole, Mail, Sparkles } from 'lucide-react';
import { signIn } from '@/lib/auth';
import { useAuth } from '@/lib/auth-context';
import { useRouter } from 'next/navigation';

export default function SignInPage() {
  const { user, loading } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const router = useRouter();

  useEffect(() => {
    if (!loading && user) {
      router.replace('/');
    }
  }, [user, loading, router]);

  if (loading || user) {
    return <div className="min-h-screen flex items-center justify-center">Loading...</div>;
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    try {
      await signIn(email, password);
      router.push('/');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center glass-panel p-6">
      <div className="w-full max-w-md">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <Sparkles className="h-4 w-4" />
            <h1 className="text-2xl font-bold text-orbitron">Ascend</h1>
          </div>
          <div className="text-muted-foreground/50">
            Study Tracker
          </div>
        </div>

        <h2 className="text-xl font-bold text-orbitron mb-6">Welcome back</h2>
        <p className="text-muted-foreground mb-6">
          Sign in to continue your study streak.
        </p>

        {error && (
          <div className="bg-destructive/20 border border-destructive/30 text-destructive px-4 py-3 rounded-lg mb-6">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5">
          <div className="space-y-2">
            <label htmlFor="email" className="text-muted-foreground font-medium">
              Email
            </label>
            <div className="flex items-center gap-2">
              <Mail className="h-4 w-4 text-muted-foreground/50" />
              <input
                id="email"
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
                disabled={isLoading}
                className="flex-1 px-4 py-3 bg-secondary-card/50 border border-muted-foreground/20 rounded-md focus:ring-2 focus:ring-primary/30 focus:border-primary/50 text-muted-foreground"
              />
            </div>
          </div>

          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <label htmlFor="password" className="text-muted-foreground font-medium">
                Password
              </label>
              <button
                type="button"
                onClick={() => setShowPassword((value) => !value)}
                className="text-muted-foreground/50 hover:text-muted-foreground"
              >
                {showPassword ? 'Hide' : 'Show'}
              </button>
            </div>
            <div className="flex items-center gap-2">
              <LockKeyhole className="h-4 w-4 text-muted-foreground/50" />
              <input
                id="password"
                type={showPassword ? 'text' : 'password'}
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                disabled={isLoading}
                className="flex-1 px-4 py-3 bg-secondary-card/50 border border-muted-foreground/20 rounded-md focus:ring-2 focus:ring-primary/30 focus:border-primary/50 text-muted-foreground"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="w-full glowing-border px-6 py-3 text-primary font-medium hover:bg-primary/20"
          >
            {isLoading ? 'Signing in...' : 'Sign in'}
          </button>
        </form>

        <div className="mt-6 text-center">
          <span className="text-muted-foreground">Don’t have an account?</span>
          <a href="/sign-up" className="text-primary font-medium hover:text-primary/80">
            Sign up
          </a>
        </div>
      </div>
    </div>
  );
}