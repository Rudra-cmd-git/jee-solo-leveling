'use client';

import * as React from 'react';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Eye, EyeOff, LockKeyhole, Mail, UserRound } from 'lucide-react';
import { signUp } from '@/lib/auth';
import { useAuth } from '@/lib/auth-context';
import { AuthShell } from '@/components/AuthShell';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import { useToast } from '@/components/ui/toast';

export default function SignUpPage() {
  const { user, loading } = useAuth();
  const router = useRouter();
  const { toast } = useToast();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (!loading && user) {
      router.replace('/');
    }
  }, [user, loading, router]);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);

    if (password.length < 6) {
      setError('Password must be at least 6 characters long.');
      return;
    }

    setIsLoading(true);
    try {
      await signUp(email, password, name.trim());
      toast({
        title: 'Player registered',
        description:
          'If email confirmation is enabled, confirm your inbox first — then sign in to start your first quest.',
        variant: 'success',
      });
      router.push('/sign-in');
    } catch (err) {
      setError(
        err instanceof Error ? err.message : 'Sign-up failed. Try again.',
      );
    } finally {
      setIsLoading(false);
    }
  };

  if (loading || user) {
    return (
      <main className="flex flex-1 items-center justify-center px-4">
        <div className="w-full max-w-md space-y-4" aria-busy="true">
          <Skeleton className="mx-auto h-10 w-40" />
          <Skeleton className="h-72 w-full rounded-xl" />
        </div>
      </main>
    );
  }

  return (
    <AuthShell
      eyebrow="NEW PLAYER"
      title="Begin your ascent"
      subtitle="Create an account and accept your first quest."
      footerPrompt="Already a player?"
      footerLinkLabel="Sign in"
      footerHref="/sign-in"
    >
      {error && (
        <div
          role="alert"
          className="mb-4 rounded-md border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300"
        >
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label
            htmlFor="name"
            className="block text-sm font-medium text-foreground mb-1"
          >
            Player name
          </label>
          <div className="relative">
            <UserRound
              className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-primary"
              aria-hidden
            />
            <Input
              id="name"
              type="text"
              autoComplete="name"
              required
              maxLength={60}
              value={name}
              onChange={(event) => setName(event.target.value)}
              placeholder="e.g. Sung Jinwoo"
              disabled={isLoading}
              className="pl-10"
            />
          </div>
          <p className="mt-1 text-xs text-muted-foreground">
            This is the name shown on the leaderboard.
          </p>
        </div>

        <div>
          <label
            htmlFor="email"
            className="block text-sm font-medium text-foreground mb-1"
          >
            Email
          </label>
          <div className="relative">
            <Mail
              className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-primary"
              aria-hidden
            />
            <Input
              id="email"
              type="email"
              autoComplete="email"
              required
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="you@example.com"
              disabled={isLoading}
              className="pl-10"
            />
          </div>
        </div>

        <div>
          <label
            htmlFor="password"
            className="block text-sm font-medium text-foreground mb-1"
          >
            Password
          </label>
          <div className="relative">
            <LockKeyhole
              className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-primary"
              aria-hidden
            />
            <Input
              id="password"
              type={showPassword ? 'text' : 'password'}
              autoComplete="new-password"
              required
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              placeholder="At least 6 characters"
              disabled={isLoading}
              className="pl-10 pr-11"
            />
            <button
              type="button"
              onClick={() => setShowPassword((value) => !value)}
              aria-label={showPassword ? 'Hide password' : 'Show password'}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
            >
              {showPassword ? (
                <EyeOff className="h-4 w-4" aria-hidden />
              ) : (
                <Eye className="h-4 w-4" aria-hidden />
              )}
            </button>
          </div>
        </div>

        <Button type="submit" isLoading={isLoading} className="w-full" size="lg">
          {isLoading ? 'Creating account…' : 'Create Account'}
        </Button>
      </form>
    </AuthShell>
  );
}
