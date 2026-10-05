'use client';

import { useEffect, useState, useCallback } from 'react';
import { useAuth } from '@/lib/auth-context';
import { supabase } from '@/lib/supabase';
import { getRankProgress, formatNumber } from '@/lib/utils';
import { useRouter } from 'next/navigation';

type TaskStat = {
  status: string;
  xp_value: number;
};

type SubmissionStat = {
  ai_verdict: string;
  tasks: Array<{ xp_value: number }>;
};

type UserProfile = {
  id: string;
  name: string | null;
  total_xp: number;
  rank: string;
  [key: string]: unknown;
};

type Stats = {
  tasks: {
    total: number;
    pending: number;
    approved: number;
    rejected: number;
    totalXpAvailable: number;
  };
  submissions: {
    total: number;
    approved: number;
    rejected: number;
    pending: number;
    totalXpEarned: number;
  };
  xpLog: {
    totalEntries: number;
    totalXpChange: number;
  };
};

export default function ProfilePage() {
  const { user, loading } = useAuth();
  const router = useRouter();
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [stats, setStats] = useState<Stats | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const fetchProfile = useCallback(async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('id', user.id)
        .single();

      if (error) throw error;
      setProfile(data);
    } catch (error) {
      console.error('Error fetching profile:', error);
    }
  }, [user]);

  const fetchStats = useCallback(async () => {
    if (!user) return;

    try {
      // Get task stats
      const { data: tasksData, error: tasksError } = await supabase
        .from('tasks')
        .select('status, xp_value')
        .eq('user_id', user.id);

      if (tasksError) throw tasksError;

      const typedTasksData = (tasksData ?? []) as TaskStat[];

      // Get submission stats
      const { data: submissionsData, error: submissionsError } = await supabase
        .from('submissions')
        .select('ai_verdict, tasks!inner(xp_value)')
        .eq('tasks.user_id', user.id);

      if (submissionsError) throw submissionsError;

      // Get XP log stats
      const { data: xpLogData, error: xpLogError } = await supabase
        .from('xp_log')
        .select('xp_change')
        .eq('user_id', user.id);

      if (xpLogError) throw xpLogError;

      const typedSubmissionsData = (submissionsData ?? []) as SubmissionStat[];

      const stats = {
        tasks: {
          total: typedTasksData.length,
          pending: typedTasksData.filter(t => t.status === 'pending').length,
          approved: typedTasksData.filter(t => t.status === 'approved').length,
          rejected: typedTasksData.filter(t => t.status === 'rejected').length,
          totalXpAvailable: typedTasksData.reduce((sum, t) => sum + (t.xp_value ?? 0), 0)
        },
        submissions: {
          total: typedSubmissionsData.length,
          approved: typedSubmissionsData.filter(s => s.ai_verdict === 'approved').length,
          rejected: typedSubmissionsData.filter(s => s.ai_verdict === 'rejected').length,
          pending: typedSubmissionsData.filter(s => s.ai_verdict === 'pending').length,
          totalXpEarned: typedSubmissionsData
            .filter(s => s.ai_verdict === 'approved')
            .reduce((sum, s) => sum + (s.tasks?.[0]?.xp_value ?? 0), 0)
        },
        xpLog: {
          totalEntries: xpLogData.length,
          totalXpChange: xpLogData.reduce((sum, entry) => sum + entry.xp_change, 0)
        }
      };

      setStats(stats);
    } catch (error) {
      console.error('Error fetching stats:', error);
    }
  }, [user]);

  useEffect(() => {
    if (!loading && !user) {
      router.replace('/sign-in');
      return;
    }

    if (user) {
      void (async () => {
        setIsLoading(true);
        try {
          await Promise.all([
            fetchProfile(),
            fetchStats(),
          ]);
        } finally {
          setIsLoading(false);
        }
      })();
    } else {
      void (async () => {
        setProfile(null);
        setStats(null);
        setIsLoading(false);
      })();
    }
  }, [user, loading, router, fetchProfile, fetchStats]);

  if (loading) {
    return <div>Loading...</div>;
  }

  if (!user) {
    return null;
  }

  // If still loading data, show skeleton
  if (isLoading && !profile) {
    return <div>Loading profile...</div>;
  }

  const rankProgress = getRankProgress(profile?.total_xp || 0);

  return (
    <div className="page">
      <main className="main">
        {/* Header */}
        <div className="mb-6">
          <div className="flex items-center space-x-4 mb-4">
            <div className="w-14 h-14 bg-secondary-card/50 flex items-center justify-center text-muted-foreground">
              {profile?.name?.charAt(0) ?? 'U'}
            </div>
            <div>
              <h1 className="text-2xl font-bold text-orbitron">
                {profile?.name || 'Studier'}&apos;s Profile
              </h1>
              <p className="text-muted-foreground">
                Rank:
                <span className={`rank-badge rank-${profile?.rank?.toLowerCase() || 'e'} text-xs`}>
                  {profile?.rank || 'E'}
                </span>
                • XP: {formatNumber(profile?.total_xp || 0)}
              </p>
            </div>
          </div>

          {/* Rank Progress */}
          <div className="glass-panel p-6">
            <h2 className="text-xl font-bold text-orbitron mb-4">Rank Progress</h2>
            <div className="space-y-4">
              <div className="flex items-center space-x-4">
                <div className="w-10 h-10 flex items-center justify-center bg-primary/20 text-primary rounded">
                  {profile?.rank || 'E'}
                </div>
                <div>
                  <h3 className="font-bold text-orbitron">{rankProgress.nextRank ?? 'MAX'}</h3>
                  <p className="text-sm text-muted-foreground">
                    {rankProgress.xpToNextRank > 0
                      ? `${formatNumber(rankProgress.xpToNextRank)} XP to go`
                      : 'Maximum rank achieved!'}
                  </p>
                </div>
              </div>

              <div className="w-full bg-secondary-card/50 rounded-full h-2.5">
                <div
                  className="bg-primary/50 h-2.5 rounded-full"
                  style={{ width: `${rankProgress.progress}%` }}
                ></div>
              </div>
              <p className="text-sm text-muted-foreground text-center">
                {rankProgress.progress.toFixed(0)}% to next rank
              </p>
            </div>
          </div>
        </div>

          {/* Stats Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {/* Tasks Stats */}
            <div className="glass-panel p-6">
              <h3 className="text-lg font-bold text-orbitron mb-4">Tasks</h3>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Total</span>
                  <span className="font-medium">{stats?.tasks?.total || 0}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Pending</span>
                  <span className="text-yellow-400 font-medium">{stats?.tasks?.pending || 0}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Approved</span>
                  <span className="text-green-400 font-medium">{stats?.tasks?.approved || 0}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Rejected</span>
                  <span className="text-red-400 font-medium">{stats?.tasks?.rejected || 0}</span>
                </div>
                <div className="flex justify-between pt-4 border-t">
                  <span className="text-muted-foreground">Total XP Available</span>
                  <span className="font-medium text-primary">
                    {formatNumber(stats?.tasks?.totalXpAvailable || 0)}
                  </span>
                </div>
              </div>
            </div>

            {/* Submissions Stats */}
            <div className="glass-panel p-6">
              <h3 className="text-lg font-bold text-orbitron mb-4">Submissions</h3>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Total</span>
                  <span className="font-medium">{stats?.submissions?.total || 0}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Pending Review</span>
                  <span className="text-yellow-400 font-medium">{stats?.submissions?.pending || 0}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Approved</span>
                  <span className="text-green-400 font-medium">{stats?.submissions?.approved || 0}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Rejected</span>
                  <span className="text-red-400 font-medium">{stats?.submissions?.rejected || 0}</span>
                </div>
                <div className="flex justify-between pt-4 border-t">
                  <span className="text-muted-foreground">Total XP Earned</span>
                  <span className="font-medium text-primary">
                    {formatNumber(stats?.submissions?.totalXpEarned || 0)}
                  </span>
                </div>
              </div>
            </div>

            {/* XP Log Stats */}
            <div className="glass-panel p-6">
              <h3 className="text-lg font-bold text-orbitron mb-4">XP History</h3>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Total Entries</span>
                  <span className="font-medium">{stats?.xpLog?.totalEntries || 0}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Total XP Change</span>
                  <span className="font-medium text-primary">
                    {formatNumber(stats?.xpLog?.totalXpChange || 0)}
                  </span>
                </div>
              </div>
            </div>
          </div>

          {/* Back to Dashboard */}
          <div className="mt-8">
            <button
              onClick={() => router.push('/')}
              className="glowing-border px-5 py-3 text-primary font-medium hover:bg-primary/20"
            >
              ← Back to Dashboard
            </button>
          </div>
        </main>
      </div>
  );
}