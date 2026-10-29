'use client';

import * as React from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { LayoutDashboard, LogOut, Swords, UserRound } from 'lucide-react';
import { signOut } from '@/lib/auth';
import type { Profile } from '@/lib/types';
import { formatNumber, cn } from '@/lib/utils';
import { Avatar } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { RankBadge } from '@/components/ui/rank-badge';
import { useToast } from '@/components/ui/toast';

const NAV = [
  { href: '/', label: 'Quests', Icon: LayoutDashboard },
  { href: '/profile', label: 'Player', Icon: UserRound },
] as const;

export function AppHeader({ profile }: { profile: Profile | null }) {
  const pathname = usePathname();
  const router = useRouter();
  const { toast } = useToast();
  const [signingOut, setSigningOut] = React.useState(false);

  const handleSignOut = async () => {
    setSigningOut(true);
    try {
      await signOut();
      router.replace('/sign-in');
    } catch (error) {
      toast({
        title: 'Sign out failed',
        description:
          error instanceof Error ? error.message : 'Please try again.',
        variant: 'error',
      });
      setSigningOut(false);
    }
  };

  return (
    <header className="sticky top-0 z-40 border-b border-primary/15 bg-background/80 backdrop-blur">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-3 px-4 py-3 sm:px-6">
        <Link href="/" className="flex items-center gap-2">
          <Swords className="h-6 w-6 text-primary" aria-hidden />
          <span className="font-orbitron text-sm font-bold tracking-widest text-foreground sm:text-base">
            JEE SOLO LEVELING
          </span>
        </Link>

        <nav
          aria-label="Primary"
          className="order-3 flex w-full gap-1 sm:order-2 sm:w-auto sm:ml-4"
        >
          {NAV.map(({ href, label, Icon }) => (
            <Link
              key={href}
              href={href}
              aria-current={pathname === href ? 'page' : undefined}
              className={cn(
                'inline-flex items-center gap-1.5 rounded-md px-3 py-1.5 text-sm font-medium transition-colors',
                pathname === href
                  ? 'bg-primary/15 text-primary'
                  : 'text-muted-foreground hover:bg-white/5 hover:text-foreground',
              )}
            >
              <Icon className="h-4 w-4" aria-hidden />
              {label}
            </Link>
          ))}
        </nav>

        <div className="order-2 ml-auto flex items-center gap-3 sm:order-3">
          {profile && (
            <>
              <span className="hidden font-orbitron text-sm text-primary md:inline">
                {formatNumber(profile.total_xp)} XP
              </span>
              <RankBadge rank={profile.rank} size="sm" />
              <Avatar name={profile.name} size={32} />
              <span className="hidden max-w-[120px] truncate text-sm text-foreground lg:inline">
                {profile.name}
              </span>
            </>
          )}
          <Button
            variant="outline"
            size="sm"
            onClick={handleSignOut}
            isLoading={signingOut}
          >
            <LogOut className="h-4 w-4" aria-hidden />
            <span className="hidden sm:inline">Log out</span>
          </Button>
        </div>
      </div>
    </header>
  );
}

export default AppHeader;
