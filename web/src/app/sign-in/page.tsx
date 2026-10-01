'use client';

import { useEffect, useState } from 'react';
import { Moon, SunMedium, LockKeyhole, Mail, Sparkles } from 'lucide-react';
import { signIn } from '@/lib/auth';
import { useAuth } from '@/lib/auth-context';
import { useRouter } from 'next/navigation';

export default function SignInPage() {
  const { user, loading } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [theme, setTheme] = useState<'light' | 'dark'>('light');
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

  const isDark = theme === 'dark';

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    try {
      await signIn(email, password);
      router.push('/');
    } catch (err: any) {
      setError(err.message || 'An error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: isDark
          ? 'radial-gradient(circle at top, #1f2a3a 0%, #0b1220 46%, #060b14 100%)'
          : 'radial-gradient(circle at top, #eef7ff 0%, #f3f7ff 30%, #edf1f7 100%)',
        color: isDark ? '#edf4ff' : '#111827',
        padding: '32px 20px',
        transition: 'all 0.25s ease',
        fontFamily: 'var(--font-geist-sans), sans-serif',
      }}
    >
      <div style={{ position: 'absolute', top: 24, right: 24 }}>
        <button
          type="button"
          onClick={() => setTheme(isDark ? 'light' : 'dark')}
          aria-label={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 8,
            border: `1px solid ${isDark ? '#334155' : '#dbe4f0'}`,
            background: isDark ? '#0f172a' : '#ffffff',
            color: isDark ? '#e2e8f0' : '#111827',
            borderRadius: 999,
            padding: '10px 14px',
            fontSize: 12,
            fontWeight: 700,
            letterSpacing: 0.5,
            cursor: 'pointer',
            boxShadow: isDark ? '0 10px 20px rgba(15, 23, 42, 0.35)' : '0 8px 18px rgba(15, 23, 42, 0.08)',
          }}
        >
          {isDark ? <SunMedium size={16} /> : <Moon size={16} />}
          {isDark ? 'Light mode' : 'Dark mode'}
        </button>
      </div>

      <div
        style={{
          width: '100%',
          maxWidth: 440,
          position: 'relative',
          borderRadius: 28,
          overflow: 'hidden',
          background: isDark ? 'rgba(15, 23, 42, 0.78)' : 'rgba(255, 255, 255, 0.8)',
          border: `1px solid ${isDark ? 'rgba(148, 163, 184, 0.20)' : 'rgba(148, 163, 184, 0.25)'}`,
          boxShadow: isDark
            ? '0 30px 80px rgba(2, 6, 23, 0.65)'
            : '0 25px 60px rgba(15, 23, 42, 0.12)',
          backdropFilter: 'blur(14px)',
        }}
      >
        <div
          style={{
            padding: '28px 28px 26px',
            borderBottom: `1px solid ${isDark ? 'rgba(148, 163, 184, 0.18)' : 'rgba(148, 163, 184, 0.18)'}`,
            background: isDark ? 'rgba(15, 23, 42, 0.22)' : 'rgba(255,255,255,0.35)',
          }}
        >
          <div
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 10,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: 800,
              textTransform: 'uppercase',
              color: isDark ? '#8ec5ff' : '#4f46e5',
            }}
          >
            <Sparkles size={14} />
            Ascend
          </div>
          <h1
            style={{
              margin: '16px 0 6px',
              fontSize: 36,
              lineHeight: 1.05,
              fontWeight: 800,
              letterSpacing: '-0.05em',
            }}
          >
            Welcome back
          </h1>
          <p
            style={{
              margin: 0,
              color: isDark ? '#b6c2d6' : '#5f6f85',
              fontSize: 14,
              lineHeight: 1.6,
            }}
          >
            Sign in to continue your study streak.
          </p>
        </div>

        <div style={{ padding: 28 }}>
          {error && (
            <div
              style={{
                marginBottom: 18,
                border: '1px solid rgba(239, 68, 68, 0.35)',
                background: isDark ? 'rgba(127, 29, 29, 0.25)' : '#fef2f2',
                color: isDark ? '#fecaca' : '#b91c1c',
                borderRadius: 12,
                padding: '10px 12px',
                fontSize: 13,
              }}
            >
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} style={{ display: 'grid', gap: 18 }}>
            <div style={{ display: 'grid', gap: 8 }}>
              <label htmlFor="email" style={{ fontSize: 12, fontWeight: 700, color: isDark ? '#dfe7f5' : '#374151' }}>
                Email
              </label>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  borderRadius: 14,
                  border: `1px solid ${isDark ? '#334155' : '#dfe7f0'}`,
                  background: isDark ? '#0f172a' : '#f8fafc',
                  padding: '0 12px',
                  height: 52,
                  transition: 'all 0.2s ease',
                  boxShadow: isDark ? 'inset 0 0 0 1px rgba(59,130,246,0.16)' : 'inset 0 0 0 1px rgba(79,70,229,0.04)',
                }}
              >
                <Mail size={17} color={isDark ? '#93c5fd' : '#6366f1'} />
                <input
                  id="email"
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  disabled={isLoading}
                  style={{
                    flex: 1,
                    border: 'none',
                    outline: 'none',
                    background: 'transparent',
                    color: isDark ? '#f8fafc' : '#111827',
                    fontSize: 15,
                  }}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gap: 8 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <label htmlFor="password" style={{ fontSize: 12, fontWeight: 700, color: isDark ? '#dfe7f5' : '#374151' }}>
                  Password
                </label>
                <button
                  type="button"
                  onClick={() => setShowPassword((value) => !value)}
                  style={{
                    background: 'transparent',
                    border: 'none',
                    color: isDark ? '#a5b4fc' : '#4f46e5',
                    fontSize: 12,
                    fontWeight: 700,
                    cursor: 'pointer',
                    padding: 0,
                  }}
                >
                  {showPassword ? 'Hide' : 'Show'}
                </button>
              </div>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  borderRadius: 14,
                  border: `1px solid ${isDark ? '#334155' : '#dfe7f0'}`,
                  background: isDark ? '#0f172a' : '#f8fafc',
                  padding: '0 12px',
                  height: 52,
                }}
              >
                <LockKeyhole size={17} color={isDark ? '#93c5fd' : '#6366f1'} />
                <input
                  id="password"
                  type={showPassword ? 'text' : 'password'}
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  disabled={isLoading}
                  style={{
                    flex: 1,
                    border: 'none',
                    outline: 'none',
                    background: 'transparent',
                    color: isDark ? '#f8fafc' : '#111827',
                    fontSize: 15,
                  }}
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={isLoading}
              style={{
                marginTop: 6,
                border: 'none',
                borderRadius: 14,
                background: isDark
                  ? 'linear-gradient(135deg, #60a5fa 0%, #8b5cf6 100%)'
                  : 'linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%)',
                color: '#ffffff',
                height: 52,
                fontSize: 15,
                fontWeight: 800,
                letterSpacing: 0.2,
                cursor: isLoading ? 'not-allowed' : 'pointer',
                opacity: isLoading ? 0.75 : 1,
                transition: 'transform 0.2s ease, opacity 0.2s ease',
                boxShadow: '0 16px 30px rgba(99, 102, 241, 0.35)',
              }}
            >
              {isLoading ? 'Signing in...' : 'Sign in'}
            </button>
          </form>

          <div
            style={{
              marginTop: 20,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 6,
              color: isDark ? '#bfdbfe' : '#475569',
              fontSize: 13,
            }}
          >
            <span>Don’t have an account?</span>
            <a href="/sign-up" style={{ color: isDark ? '#93c5fd' : '#4f46e5', fontWeight: 700, textDecoration: 'none' }}>
              Sign up
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}