'use client';

import { useEffect, useState } from 'react';
import { signUp } from '@/lib/auth';
import { useAuth } from '@/lib/auth-context';
import { useRouter } from 'next/navigation';

export default function SignUpPage() {
  const { user, loading } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
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
      await signUp(email, password, name);
      // After sign up, redirect to sign in page for verification
      router.push('/sign-in');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center glass-panel p-6">
      <div className="w-full max-w-md">
        <h2 className="text-2xl font-bold text-orbitron text-center">Create Account</h2>

        {error && (
          <div className="bg-destructive/20 border border-destructive/30 text-destructive px-4 py-3 rounded-lg">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5">
          <div className="space-y-2">
            <label htmlFor="name" className="text-muted-foreground font-medium">
              Name
            </label>
            <input
              id="name"
              type="text"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full px-4 py-3 bg-secondary-card/50 border border-muted-foreground/20 rounded-md focus:ring-2 focus:ring-primary/30 focus:border-primary/50 text-muted-foreground"
              disabled={isLoading}
            />
          </div>

          <div className="space-y-2">
            <label htmlFor="email" className="text-muted-foreground font-medium">
              Email
            </label>
            <input
              id="email"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-3 bg-secondary-card/50 border border-muted-foreground/20 rounded-md focus:ring-2 focus:ring-primary/30 focus:border-primary/50 text-muted-foreground"
              disabled={isLoading}
            />
          </div>

          <div className="space-y-2">
            <label htmlFor="password" className="text-muted-foreground font-medium">
              Password
            </label>
            <input
              id="password"
              type="password"
              required
              minLength={6}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-4 py-3 bg-secondary-card/50 border border-muted-foreground/20 rounded-md focus:ring-2 focus:ring-primary/30 focus:border-primary/50 text-muted-foreground"
              disabled={isLoading}
            />
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="w-full glowing-border px-6 py-3 text-primary font-medium hover:bg-primary/20"
          >
            {isLoading ? 'Creating account...' : 'Sign Up'}
          </button>
        </form>

        <div className="text-sm text-muted-foreground text-center">
          Already have an account?{' '}
          <a href="/sign-in" className="text-primary hover:text-primary/80">
            Sign in
          </a>
        </div>
      </div>
    </div>
  );
}