'use client';

import * as React from 'react';
import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { CheckCircle2, Clock, History, Save, XCircle, Zap } from 'lucide-react';
import { useAuth } from '@/lib/auth-context';
import { supabase } from '@/lib/supabase';
import { updateUser } from '@/lib/auth';
import { ensureProfile } from '@/lib/profile';
import {
  RANKS,
  RANK_THRESHOLDS,
  getRank,
  formatNumber,
  formatDate,
  cn,
} from '@/lib/utils';
import type { Profile, SubmissionWithTask, Task, XpLogEntry } from '@/lib/types';
import { AppHeader } from '@/components/AppHeader';
import { ConfigBanner } from '@/components/ConfigBanner';
import { Avatar } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { RankBadge } from '@/components/ui/rank-badge';
import { Skeleton } from '@/components/ui/skeleton';
import { SystemPanel } from '@/components/ui/system-panel';
import { XPBar } from '@/components/ui/xp-bar';
import { useToast } from '@/components/ui/toast';

interface DerivedStats {
  tasksTotal: number;
  tasksPending: number;
  tasksApproved: number;
  tasksRejected: number;
  submissionsTotal: number;
  submissionsApproved: number;
  submissionsRejected: number;
  submissionsPending: number;
  xpEarnedFromProofs: number;
  xpLogTotal: number;
}

function ProfileSkeleton() {
  return (
    <div className="mx-auto w-full max-w-6xl space-y-6 px-4 py-8 sm:px-6" aria-busy="true">
      <span className="sr-only">Loading your profile…</span>
      <Skeleton className="h-36 w-full rounded-xl" />
      <div className="grid gap-6 md:grid-cols-3">
        {[0, 1, 2].map((i) => (
          <Skeleton key={i} className="h-48 rounded-xl" />
        ))}
      </div>
    </div>
  );
}

interface ProfileData {
  stats: DerivedStats;
  xpHistory: XpLogEntry[];
}

/** Pure fetcher + stats derivation: returns data, never touches state. */
async function fetchProfileData(userId: string): Promise<ProfileData> {
  const [tasksResult, submissionsResult, xpLogResult] = await Promise.all([
    supabase.from('tasks').select('*').eq('user_id', userId),
    supabase
      .from('submissions')
      .select('*, tasks!inner (title, xp_value)')
      .eq('tasks.user_id', userId),
    supabase
      .from('xp_log')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(10),
  ]);

  if (tasksResult.error) throw tasksResult.error;
  if (submissionsResult.error) throw submissionsResult.error;
  if (xpLogResult.error) throw xpLogResult.error;

  const tasksData = (tasksResult.data ?? []) as unknown as Task[];
  const submissionsData = (submissionsResult.data ??
    []) as unknown as SubmissionWithTask[];
  const xpLogData = (xpLogResult.data ?? []) as unknown as XpLogEntry[];

  return {
    xpHistory: xpLogData,
    stats: {
      tasksTotal: tasksData.length,
      tasksPending: tasksData.filter((t) => t.status === 'pending').length,
      tasksApproved: tasksData.filter((t) => t.status === 'approved').length,
      tasksRejected: tasksData.filter((t) => t.status === 'rejected').length,
      submissionsTotal: submissionsData.length,
      submissionsApproved: submissionsData.filter(
        (s) => s.ai_verdict === 'approved',
      ).length,
      submissionsRejected: submissionsData.filter(
        (s) => s.ai_verdict === 'rejected',
      ).length,
      submissionsPending: submissionsData.filter(
        (s) => s.ai_verdict === 'pending' || s.ai_verdict === null,
      ).length,
      xpEarnedFromProofs: submissionsData
        .filter((s) => s.ai_verdict === 'approved')
        .reduce((sum, s) => sum + s.tasks.xp_value, 0),
      xpLogTotal: xpLogData.reduce((sum, entry) => sum + entry.xp_change, 0),
    },
  };
}

export default function ProfilePage() {
  const { user, loading } = useAuth();
  const router = useRouter();
  const { toast } = useToast();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [nameDraft, setNameDraft] = useState('');
  const [savingName, setSavingName] = useState(false);
  const [stats, setStats] = useState<DerivedStats | null>(null);
  const [xpHistory, setXpHistory] = useState<XpLogEntry[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const applyData = useCallback(
    (profileData: Profile | null, data: ProfileData) => {
      setProfile(profileData);
      setNameDraft(profileData?.name ?? '');
      setXpHistory(data.xpHistory);
      setStats(data.stats);
      setLoadError(null);
    },
    [],
  );

  useEffect(() => {
    if (!loading && !user) {
      router.replace('/sign-in');
      return;
    }
    if (!user) return;

    let cancelled = false;
    Promise.all([ensureProfile(user), fetchProfileData(user.id)])
      .then(([profileData, data]) => {
        if (!cancelled) applyData(profileData, data);
      })
      .catch((error: unknown) => {
        if (cancelled) return;
        console.error('Error loading profile:', error);
        setLoadError(
          error instanceof Error
            ? error.message
            : 'Could not load your profile. Check your Supabase setup and migrations.',
        );
      })
      .finally(() => {
        if (!cancelled) setIsLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [user, loading, router, applyData]);

  const handleSaveName = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!user || !profile) return;
    const trimmed = nameDraft.trim();
    if (!trimmed || trimmed === profile.name) return;

    setSavingName(true);
    try {
      const { error } = await supabase
        .from('users')
        .update({ name: trimmed })
        .eq('id', user.id);
      if (error) throw error;
      await updateUser({ name: trimmed }).catch(() => undefined);
      setProfile({ ...profile, name: trimmed });
      toast({
        title: 'Player name updated',
        description: `You are now known as ${trimmed}.`,
        variant: 'success',
      });
    } catch (error) {
      toast({
        title: 'Could not save name',
        description: error instanceof Error ? error.message : 'Try again.',
        variant: 'error',
      });
    } finally {
      setSavingName(false);
    }
  };

  if (loading || !user) {
    return (
      <>
        <AppHeader profile={null} />
        <ProfileSkeleton />
      </>
    );
  }

  const totalXp = profile?.total_xp ?? 0;
  const currentRank = profile?.rank ?? getRank(totalXp);

  return (
    <>
      <AppHeader profile={profile} />
      <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-8 sm:px-6">
        <ConfigBanner />

        {loadError && (
          <div
            role="alert"
            className="mb-6 rounded-xl border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300"
          >
            {loadError}
          </div>
        )}

        {isLoading && !profile ? (
          <ProfileSkeleton />
        ) : (
          <div className="space-y-6">
            {/* Identity */}
            <SystemPanel title="Player Card">
              <div className="flex flex-col gap-6 md:flex-row md:items-center">
                <Avatar name={profile?.name} size={72} />
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-3">
                    <h1 className="text-2xl font-bold text-foreground">
                      {profile?.name ?? 'Player'}
                    </h1>
                    <RankBadge rank={currentRank} withLabel />
                  </div>
                  <p className="mt-1 text-sm text-muted-foreground">
                    {formatNumber(totalXp)} XP
                    {(profile?.current_streak ?? 0) > 0 &&
                      ` · ${profile?.current_streak}-day streak`}
                    {profile?.created_at &&
                      ` · Awakened ${formatDate(profile.created_at)}`}
                  </p>
                  <XPBar xp={totalXp} className="mt-4 max-w-xl" />

                  <form
                    onSubmit={handleSaveName}
                    className="mt-5 flex max-w-xl flex-wrap items-end gap-3"
                  >
                    <div className="min-w-[220px] flex-1">
                      <label
                        htmlFor="player-name"
                        className="mb-1 block text-sm font-medium text-foreground"
                      >
                        Player name
                      </label>
                      <Input
                        id="player-name"
                        value={nameDraft}
                        onChange={(event) => setNameDraft(event.target.value)}
                        maxLength={60}
                        disabled={savingName}
                      />
                    </div>
                    <Button
                      type="submit"
                      isLoading={savingName}
                      disabled={
                        !nameDraft.trim() || nameDraft.trim() === profile?.name
                      }
                    >
                      <Save className="h-4 w-4" aria-hidden /> Save
                    </Button>
                  </form>
                </div>
              </div>
            </SystemPanel>

            {/* Rank ladder */}
            <SystemPanel title="Rank Ladder">
              <ol className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                {RANKS.map((rank) => {
                  const reached = totalXp >= RANK_THRESHOLDS[rank];
                  const isCurrent = rank === currentRank;
                  return (
                    <li
                      key={rank}
                      className={cn(
                        'flex items-center gap-3 rounded-lg border p-3',
                        isCurrent
                          ? 'border-primary/60 bg-primary/10'
                          : 'border-border bg-black/30',
                        !reached && 'opacity-60',
                      )}
                    >
                      <RankBadge rank={rank} />
                      <div>
                        <p className="text-sm font-semibold text-foreground">
                          {rank} Rank{isCurrent ? ' — you are here' : ''}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          {formatNumber(RANK_THRESHOLDS[rank])}+ XP
                        </p>
                      </div>
                    </li>
                  );
                })}
              </ol>
            </SystemPanel>

            {/* Stats */}
            <div className="grid gap-6 md:grid-cols-3">
              <SystemPanel title="Quests">
                <dl className="space-y-3 text-sm">
                  <div className="flex justify-between">
                    <dt className="text-muted-foreground">Total created</dt>
                    <dd className="font-semibold">{stats?.tasksTotal ?? 0}</dd>
                  </div>
                  <div className="flex justify-between">
                    <dt className="inline-flex items-center gap-1 text-muted-foreground">
                      <Clock className="h-3.5 w-3.5 text-yellow-300" aria-hidden /> Active
                    </dt>
                    <dd className="font-semibold text-yellow-300">
                      {stats?.tasksPending ?? 0}
                    </dd>
                  </div>
                  <div className="flex justify-between">
                    <dt className="inline-flex items-center gap-1 text-muted-foreground">
                      <CheckCircle2 className="h-3.5 w-3.5 text-green-300" aria-hidden /> Completed
                    </dt>
                    <dd className="font-semibold text-green-300">
                      {stats?.tasksApproved ?? 0}
                    </dd>
                  </div>
                  <div className="flex justify-between">
                    <dt className="inline-flex items-center gap-1 text-muted-foreground">
                      <XCircle className="h-3.5 w-3.5 text-red-300" aria-hidden /> Closed
                    </dt>
                    <dd className="font-semibold text-red-300">
                      {stats?.tasksRejected ?? 0}
                    </dd>
                  </div>
                </dl>
              </SystemPanel>

              <SystemPanel title="Proofs">
                <dl className="space-y-3 text-sm">
                  <div className="flex justify-between">
                    <dt className="text-muted-foreground">Total submitted</dt>
                    <dd className="font-semibold">
                      {stats?.submissionsTotal ?? 0}
                    </dd>
                  </div>
                  <div className="flex justify-between">
                    <dt className="text-muted-foreground">Pending review</dt>
                    <dd className="font-semibold text-yellow-300">
                      {stats?.submissionsPending ?? 0}
                    </dd>
                  </div>
                  <div className="flex justify-between">
                    <dt className="text-muted-foreground">Approved</dt>
                    <dd className="font-semibold text-green-300">
                      {stats?.submissionsApproved ?? 0}
                    </dd>
                  </div>
                  <div className="flex justify-between">
                    <dt className="text-muted-foreground">Rejected</dt>
                    <dd className="font-semibold text-red-300">
                      {stats?.submissionsRejected ?? 0}
                    </dd>
                  </div>
                  <div className="flex justify-between border-t border-border pt-3">
                    <dt className="text-muted-foreground">XP from proofs</dt>
                    <dd className="font-orbitron font-semibold text-primary">
                      {formatNumber(stats?.xpEarnedFromProofs ?? 0)}
                    </dd>
                  </div>
                </dl>
              </SystemPanel>

              <SystemPanel title="XP Ledger">
                <dl className="space-y-3 text-sm">
                  <div className="flex justify-between">
                    <dt className="text-muted-foreground">Lifetime XP</dt>
                    <dd className="font-orbitron font-semibold text-primary">
                      {formatNumber(totalXp)}
                    </dd>
                  </div>
                  <div className="flex justify-between">
                    <dt className="text-muted-foreground">Recent ledger sum</dt>
                    <dd className="font-semibold">
                      {formatNumber(stats?.xpLogTotal ?? 0)} XP
                    </dd>
                  </div>
                  <div className="flex justify-between">
                    <dt className="text-muted-foreground">Current streak</dt>
                    <dd className="font-semibold">
                      {profile?.current_streak ?? 0} days
                    </dd>
                  </div>
                  <p className="pt-2 text-xs text-muted-foreground">
                    Every XP change is written to an immutable ledger by the
                    System. XP cannot be edited from the browser.
                  </p>
                </dl>
              </SystemPanel>
            </div>

            {/* XP history */}
            <SystemPanel title="Recent XP History">
              {xpHistory.length > 0 ? (
                <ul className="divide-y divide-border">
                  {xpHistory.map((entry) => (
                    <li key={entry.id} className="flex items-center gap-3 py-3">
                      <Zap
                        className={cn(
                          'h-4 w-4 shrink-0',
                          entry.xp_change >= 0 ? 'text-primary' : 'text-red-300',
                        )}
                        aria-hidden
                      />
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm text-foreground">
                          {entry.reason}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          {formatDate(entry.created_at)}
                        </p>
                      </div>
                      <span
                        className={cn(
                          'font-orbitron text-sm font-semibold',
                          entry.xp_change >= 0 ? 'text-primary' : 'text-red-300',
                        )}
                      >
                        {entry.xp_change >= 0 ? '+' : ''}
                        {formatNumber(entry.xp_change)} XP
                      </span>
                    </li>
                  ))}
                </ul>
              ) : (
                <div className="py-6 text-center">
                  <History className="mx-auto mb-3 h-10 w-10 text-muted-foreground" aria-hidden />
                  <p className="text-muted-foreground">
                    No XP earned yet. Your legend starts with the first verified proof.
                  </p>
                </div>
              )}
            </SystemPanel>
          </div>
        )}
      </main>
    </>
  );
}
