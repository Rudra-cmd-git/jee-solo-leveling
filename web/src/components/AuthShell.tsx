'use client';

import * as React from 'react';
import Link from 'next/link';
import { Swords } from 'lucide-react';
import { ConfigBanner } from '@/components/ConfigBanner';

interface AuthShellProps {
  eyebrow: string;
  title: string;
  subtitle: string;
  footerPrompt: string;
  footerLinkLabel: string;
  footerHref: string;
  children: React.ReactNode;
}

/** Shared Solo Leveling "System window" chrome for sign-in / sign-up. */
export function AuthShell({
  eyebrow,
  title,
  subtitle,
  footerPrompt,
  footerLinkLabel,
  footerHref,
  children,
}: AuthShellProps) {
  return (
    <main className="flex flex-1 flex-col items-center justify-center px-4 py-10">
      <ConfigBanner />
      <div className="glass-panel glowing-border w-full max-w-md p-8 animate-slideUp">
        <div className="mb-6 text-center">
          <Swords className="mx-auto mb-3 h-10 w-10 text-primary" aria-hidden />
          <p className="font-orbitron text-xs font-bold tracking-[0.3em] text-primary">
            [SYSTEM] {eyebrow}
          </p>
          <h1 className="mt-3 text-3xl font-bold text-foreground">{title}</h1>
          <p className="mt-2 text-sm text-muted-foreground">{subtitle}</p>
        </div>

        {children}

        <p className="mt-6 text-center text-sm text-muted-foreground">
          {footerPrompt}{' '}
          <Link
            href={footerHref}
            className="font-semibold text-primary hover:underline"
          >
            {footerLinkLabel}
          </Link>
        </p>
      </div>
      <p className="mt-6 font-orbitron text-xs tracking-widest text-muted-foreground">
        JEE SOLO LEVELING — ARISE, PLAYER
      </p>
    </main>
  );
}

export default AuthShell;
