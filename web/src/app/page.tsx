'use client';

import * as React from 'react';
import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  BookOpenCheck,
  CheckCircle2,
  Clock,
  Flame,
  Medal,
  Plus,
  ScrollText,
  Swords,
  Target,
  Trophy,
  XCircle,
  Zap,
} from 'lucide-react';
import { useAuth } from '@/lib/auth-context';
import { supabase } from '@/lib/supabase';
import { ensureProfile } from '@/lib/profile';
import { getRankProgress, formatNumber, formatDate, cn } from '@/lib/utils';
import type {
  LeaderboardEntry,
  Profile,
  SubmissionWithTask,
  Task,
} from '@/lib/types';
import { AppHeader } from '@/components/AppHeader';
import { ConfigBanner } from '@/components/ConfigBanner';
import CreateTaskModal from '@/components/CreateTaskModal';
import SubmissionModal from '@/components/SubmissionModal';
import { Avatar } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { RankBadge } from '@/components/ui/rank-badge';
import { Skeleton } from '@/components/ui/skeleton';
import { StatCard } from '@/components/ui/stat-card';
import { SystemPanel } from '@/components/ui/system-panel';
import { XPBar } from '@/components/ui/xp-bar';

function VerdictChip({ verdict }: { verdict: SubmissionWithTask['ai_verdict'] }) {
  if (verdict === 'approved') {
    return (
      <span className="inline-flex items-center gap-1 rounded-full border border-green-500/40 bg-green-500/10 px-2 py-0.5 text-xs font-semibold text-green-300">
        <CheckCircle2 className="h-3.5 w-3.5" aria-hidden /> Verified
      </span>
    );
  }
  if (verdict === 'rejected') {
    return (
      <span className="inline-flex items-center gap-1 rounded-full border border-red-500/40 bg-red-500/10 px-2 py-0.5 text-xs font-semibold text-red-300">
        <XCircle className="h-3.5 w-3.5" aria-hidden /> Rejected
      </span>
    );
  }
  return (
    <span className="inline-flex items-center gap-1 rounded-full border border-yellow-500/40 bg-yellow-500/10 px-2 py-0.5 text-xs font-semibold text-yellow-300">
      <Clock className="h-3.5 w-3.5" aria-hidden /> Pending review
    </span>
  );
}

function DashboardSkeleton() {
  return (
    <div className="mx-auto w-full max-w-6xl space-y-6 px-4 py-8 sm:px-6" aria-busy="true">
      <span className="sr-only">Loading your dashboard…</span>
      <Skeleton className="h-36 w-full rounded-xl" />
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {[0, 1, 2, 3].map((i) => (
          <Skeleton key={i} className="h-28 rounded-xl" />
        ))}
      </div>
      <Skeleton className="h-64 w-full rounded-xl" />
    </div>
  );
}

interface DashboardData {
  tasks: Task[];
  submissions: SubmissionWithTask[];
  leaderboard: LeaderboardEntry[];
}

/** Pure fetcher: returns data, never touches component state. */
async function fetchDashboardData(userId: string): Promise<DashboardData> {
  const [tasksResult, submissionsResult, leaderboardResult] =
    await Promise.all([
      supabase
        .from('tasks')
        .select('*')
        .eq('user_id', userId)
        .eq('status', 'pending')
        .order('created_at', { ascending: false }),
      supabase
        .from('submissions')
        .select('*, tasks!inner (title, xp_value)')
        .eq('tasks.user_id', userId)
        .order('submitted_at', { ascending: false })
        .limit(5),
      (async (): Promise<LeaderboardEntry[]> => {
        // Preferred: the safe `leaderboard` view from migration 002.
        const view = await supabase
          .from('leaderboard')
          .select('*')
          .order('total_xp', { ascending: false })
          .limit(10);
        if (!view.error && view.data) {
          return view.data as unknown as LeaderboardEntry[];
        }
        // Fallback for databases still on migration 001 (own row only).
        const fallback = await supabase
          .from('users')
          .select('id, name, total_xp, rank')
          .order('total_xp', { ascending: false })
          .limit(10);
        return (fallback.data ?? []) as unknown as LeaderboardEntry[];
      })(),
    ]);

  if (tasksResult.error) throw tasksResult.error;
  if (submissionsResult.error) throw submissionsResult.error;

  return {
    tasks: (tasksResult.data ?? []) as unknown as Task[],
    submissions: (submissionsResult.data ??
      []) as unknown as SubmissionWithTask[],
    leaderboard: leaderboardResult,
  };
}

export default function DashboardPage() {
  const { user, loading } = useAuth();
  const router = useRouter();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [tasks, setTasks] = useState<Task[]>([]);
  const [submissions, setSubmissions] = useState<SubmissionWithTask[]>([]);
  const [leaderboard, setLeaderboard] = useState<LeaderboardEntry[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [selectedTask, setSelectedTask] = useState<Task | null>(null);
  const [createOpen, setCreateOpen] = useState(false);

  const applyData = useCallback(
    (data: DashboardData, profileData: Profile | null) => {
      setProfile(profileData);
      setTasks(data.tasks);
      setSubmissions(data.submissions);
      setLeaderboard(data.leaderboard);
      setLoadError(null);
    },
    [],
  );

  /** Manual refresh used after creating a quest / submitting proof. */
  const loadAll = useCallback(async () => {
    if (!user) return;
    try {
      const [profileData, data] = await Promise.all([
        ensureProfile(user),
        fetchDashboardData(user.id),
      ]);
      applyData(data, profileData);
    } catch (error) {
      console.error('Error loading dashboard:', error);
      setLoadError(
        error instanceof Error
          ? error.message
          : 'Could not load your dashboard. Check your Supabase setup and migrations.',
      );
    } finally {
      setIsLoading(false);
    }
  }, [user, applyData]);

  useEffect(() => {
    if (!loading && !user) {
      router.replace('/sign-in');
      return;
    }
    if (!user) return;

    let cancelled = false;
    Promise.all([ensureProfile(user), fetchDashboardData(user.id)])
      .then(([profileData, data]) => {
        if (!cancelled) applyData(data, profileData);
      })
      .catch((error: unknown) => {
        if (cancelled) return;
        console.error('Error loading dashboard:', error);
        setLoadError(
          error instanceof Error
            ? error.message
            : 'Could not load your dashboard. Check your Supabase setup and migrations.',
        );
      })
      .finally(() => {
        if (!cancelled) setIsLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [user, loading, router, applyData]);

  if (loading || !user) {
    return (
      <>
        <AppHeader profile={null} />
        <DashboardSkeleton />
      </>
    );
  }

  const rankProgress = getRankProgress(profile?.total_xp ?? 0);
  const streak = profile?.current_streak ?? 0;

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
          <DashboardSkeleton />
        ) : (
          <div className="space-y-6">
            {/* Player banner */}
            <SystemPanel title="Player Status">
              <div className="flex flex-col gap-5 sm:flex-row sm:items-center">
                <Avatar name={profile?.name} size={64} />
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-3">
                    <h1 className="text-2xl font-bold text-foreground">
                      {profile?.name ?? 'Player'}
                    </h1>
                    <RankBadge rank={profile?.rank ?? 'E'} withLabel />
                  </div>
                  <p className="mt-1 text-sm text-muted-foreground">
                    Total XP:{' '}
                    <span className="font-orbitron text-primary">
                      {formatNumber(profile?.total_xp ?? 0)}
                    </span>
                    {streak > 0 && (
                      <>
                        {' · '}
                        <Flame className="mb-0.5 inline h-4 w-4 text-orange-400" aria-hidden />{' '}
                        {streak}-day streak
                      </>
                    )}
                  </p>
                  <XPBar xp={profile?.total_xp ?? 0} className="mt-4" />
                </div>
              </div>
            </SystemPanel>

            {/* Stats */}
            <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
              <StatCard
                title="Next Rank"
                value={rankProgress.nextRank ?? 'MAX'}
                sublabel={
                  rankProgress.xpToNextRank > 0
                    ? `${formatNumber(rankProgress.xpToNextRank)} XP to go`
                    : 'Maximum rank achieved'
                }
                icon={<Target className="h-5 w-5" aria-hidden />}
              />
              <StatCard
                title="Rank Progress"
                value={`${rankProgress.progress.toFixed(0)}%`}
                sublabel="To next rank"
                icon={<Zap className="h-5 w-5" aria-hidden />}
              />
              <StatCard
                title="Active Quests"
                value={tasks.length}
                sublabel="Awaiting proof"
                icon={<Swords className="h-5 w-5" aria-hidden />}
              />
              <StatCard
                title="Day Streak"
                value={streak}
                sublabel={streak === 1 ? 'Day in a row' : 'Days in a row'}
                icon={<Flame className="h-5 w-5" aria-hidden />}
              />
            </div>

            <div className="grid gap-6 lg:grid-cols-3">
              <div className="space-y-6 lg:col-span-2">
                {/* Active quests */}
                <SystemPanel
                  title="Active Quests"
                  action={
                    <Button size="sm" onClick={() => setCreateOpen(true)}>
                      <Plus className="h-4 w-4" aria-hidden /> New Quest
                    </Button>
                  }
                >
                  {tasks.length > 0 ? (
                    <ul className="space-y-3">
                      {tasks.map((task) => (
                        <li
                          key={task.id}
                          className="flex flex-wrap items-center gap-3 rounded-lg border border-border bg-black/30 p-4"
                        >
                          <div className="min-w-0 flex-1">
                            <p className="truncate font-semibold text-foreground">
                              {task.title}
                            </p>
                            <p className="mt-0.5 text-sm text-muted-foreground">
                              {task.subject} · Created {formatDate(task.created_at)}
                            </p>
                            <p className="mt-1 font-orbitron text-sm text-primary">
                              +{formatNumber(task.xp_value)} XP
                            </p>
                          </div>
                          <Button size="sm" onClick={() => setSelectedTask(task)}>
                            <BookOpenCheck className="h-4 w-4" aria-hidden />
                            Submit Proof
                          </Button>
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <div className="py-8 text-center">
                      <ScrollText className="mx-auto mb-3 h-10 w-10 text-muted-foreground" aria-hidden />
                      <p className="text-muted-foreground">
                        No active quests. The System awaits your next move.
                      </p>
                      <Button className="mt-4" onClick={() => setCreateOpen(true)}>
                        <Plus className="h-4 w-4" aria-hidden /> Create your first quest
                      </Button>
                    </div>
                  )}
                </SystemPanel>

                {/* Recent submissions */}
                <SystemPanel title="Recent Proofs">
                  {submissions.length > 0 ? (
                    <ul className="space-y-3">
                      {submissions.map((submission) => (
                        <li
                          key={submission.id}
                          className="rounded-lg border border-border bg-black/30 p-4"
                        >
                          <div className="flex flex-wrap items-center justify-between gap-2">
                            <p className="font-semibold text-foreground">
                              {submission.tasks.title}
                            </p>
                            <VerdictChip verdict={submission.ai_verdict} />
                          </div>
                          <p className="mt-1 text-sm text-muted-foreground">
                            Submitted {formatDate(submission.submitted_at)}
                            {submission.ai_verdict === 'approved' &&
                              ` · +${formatNumber(submission.tasks.xp_value)} XP earned`}
                          </p>
                          {submission.ai_notes && (
                            <p className="mt-1 text-sm text-muted-foreground italic">
                              System: {submission.ai_notes}
                            </p>
                          )}
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <p className="py-6 text-center text-muted-foreground">
                      No proof submitted yet. Complete a quest and show the System your work.
                    </p>
                  )}
                </SystemPanel>
              </div>

              {/* Leaderboard */}
              <SystemPanel title="Leaderboard" className="h-fit lg:sticky lg:top-24">
                {leaderboard.length > 0 ? (
                  <ol className="space-y-2">
                    {leaderboard.map((entry, index) => (
                      <li
                        key={entry.id}
                        className={cn(
                          'flex items-center gap-3 rounded-lg border p-3',
                          entry.id === user.id
                            ? 'border-primary/50 bg-primary/10'
                            : 'border-border bg-black/30',
                        )}
                      >
                        <span className="flex w-7 shrink-0 items-center justify-center">
                          {index < 3 ? (
                            <Medal
                              className={cn(
                                'h-5 w-5',
                                index === 0 && 'text-yellow-300',
                                index === 1 && 'text-gray-300',
                                index === 2 && 'text-amber-600',
                              )}
                              aria-hidden
                            />
                          ) : (
                            <span className="font-orbitron text-sm text-muted-foreground">
                              {index + 1}
                            </span>
                          )}
                        </span>
                        <Avatar name={entry.name} size={32} />
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-sm font-semibold text-foreground">
                            {entry.name}
                            {entry.id === user.id && (
                              <span className="ml-2 text-xs text-primary">(You)</span>
                            )}
                          </p>
                          <p className="text-xs text-muted-foreground">
                            {formatNumber(entry.total_xp)} XP
                            {(entry.current_streak ?? 0) > 0 &&
                              ` · ${entry.current_streak}d streak`}
                          </p>
                        </div>
                        <RankBadge rank={entry.rank} size="sm" />
                      </li>
                    ))}
                  </ol>
                ) : (
                  <div className="py-6 text-center">
                    <Trophy className="mx-auto mb-3 h-10 w-10 text-muted-foreground" aria-hidden />
                    <p className="text-muted-foreground">
                      No hunters ranked yet. Earn XP to claim the top spot.
                    </p>
                  </div>
                )}
              </SystemPanel>
            </div>
          </div>
        )}
      </main>

      <CreateTaskModal
        isOpen={createOpen}
        onClose={() => setCreateOpen(false)}
        onCreated={() => void loadAll()}
      />

      {selectedTask && (
        <SubmissionModal
          isOpen
          task={selectedTask}
          onClose={() => setSelectedTask(null)}
          onSubmitted={() => void loadAll()}
        />
      )}
    </>
  );
}
