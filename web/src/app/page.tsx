'use client';

import { useEffect, useState, useCallback } from 'react';
import { useAuth } from '@/lib/auth-context';
import { supabase } from '@/lib/supabase';
import { getRankProgress, formatNumber } from '@/lib/utils';
import { useRouter } from 'next/navigation';
import SubmissionModal from '@/components/SubmissionModal';
import CreateTaskModal from '@/components/CreateTaskModal';

type Task = {
  id: string;
  title: string;
  subject: string;
  xp_value: number;
  status?: string;
  created_at?: string;
  user_id?: string;
};

type SubmissionRow = {
  id: string;
  submitted_at: string;
  ai_verdict: 'approved' | 'rejected' | 'pending' | string;
  tasks: Array<{
    title: string;
    xp_value: number;
  }>;
};

type UserProfile = {
  id: string;
  name: string | null;
  total_xp: number;
  rank: string;
  [key: string]: unknown;
};

type LeaderboardUser = {
  id: string;
  name: string;
  total_xp: number;
  rank: string;
};

export default function DashboardPage() {
  const { user, loading } = useAuth();
  const router = useRouter();
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [tasks, setTasks] = useState<Task[]>([]);
  const [submissions, setSubmissions] = useState<SubmissionRow[]>([]);
  const [leaderboard, setLeaderboard] = useState<LeaderboardUser[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [openSubmissionModal, setOpenSubmissionModal] = useState(false);
  const [selectedTask, setSelectedTask] = useState<Task | null>(null);
  const [openCreateTaskModal, setOpenCreateTaskModal] = useState(false);

  // Fetch user profile from public.users table
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

  const fetchTasks = useCallback(async () => {
    if (!user) return;

    try {
      // Get the current session to retrieve the access token
      const {
        data: { session },
      } = await supabase.auth.getSession();

      if (!session?.access_token) {
        console.error('Failed to get authentication token');
        return;
      }

      // Call the backend API instead of direct Supabase query
      const response = await fetch('/api/tasks?status=pending&sortBy=created', {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${session.access_token}`,
        },
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to fetch tasks');
      }

      const result = await response.json();
      setTasks((result.tasks ?? []) as Task[]);
    } catch (error) {
      console.error('Error fetching tasks:', error);
    }
  }, [user]);

  const fetchSubmissions = useCallback(async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('submissions')
        .select(`
          *,
          tasks!inner (
            title,
            xp_value
          )
        `)
        .eq('tasks.user_id', user.id)
        .order('submitted_at', { ascending: false })
        .limit(5);

      if (error) throw error;
      setSubmissions((data ?? []) as SubmissionRow[]);
    } catch (error) {
      console.error('Error fetching submissions:', error);
    }
  }, [user]);

  const fetchLeaderboard = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from('users')
        .select('id, name, total_xp, rank')
        .order('total_xp', { ascending: false })
        .limit(10);

      if (error) throw error;
      setLeaderboard(data as LeaderboardUser[]);
    } catch (error) {
      console.error('Error fetching leaderboard:', error);
    }
  }, []);

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
            fetchTasks(),
            fetchSubmissions(),
            fetchLeaderboard(),
          ]);
        } finally {
          setIsLoading(false);
        }
      })();
    } else {
      void (async () => {
        setProfile(null);
        setTasks([]);
        setSubmissions([]);
        setLeaderboard([]);
        setIsLoading(false);
      })();
    }
  }, [user, loading, router, fetchProfile, fetchTasks, fetchSubmissions, fetchLeaderboard]);

  if (loading) {
    return <div>Loading...</div>;
  }

  if (!user) {
    return null;
  }

  // If still loading data, show skeleton
  if (isLoading && !profile) {
    return <div>Loading dashboard...</div>;
  }

  const rankProgress = getRankProgress(profile?.total_xp || 0);

  return (
    <div className="page">
      <main className="main">
        {/* Intro Section with User Info */}
        <div className="intro">
          <div className="flex items-center space-x-4 mb-4">
            <div className="w-12 h-12 bg-secondary-card/50 flex items-center justify-center text-muted-foreground">
              {profile?.name?.charAt(0) ?? 'U'}
            </div>
            <div>
              <h1 className="text-2xl font-bold text-orbitron">
                Welcome back, {profile?.name || 'Studier'}!
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

          {/* Stats */}
          <div className="stats-grid mb-6">
            <div className="stat-card">
              <h3 className="stat-label">Next Rank</h3>
              <p className="stat-value">
                {rankProgress.nextRank ?? 'MAX'}
                {rankProgress.nextRank && (
                  <span className={`rank-badge rank-${rankProgress.nextRank.toLowerCase()} text-xs ml-2`}>
                    {rankProgress.nextRank}
                  </span>
                )}
              </p>
              <p className="text-sm text-muted-foreground mt-1">
                {rankProgress.xpToNextRank > 0
                  ? `${formatNumber(rankProgress.xpToNextRank)} XP to go`
                  : 'Maximum rank achieved!'}
              </p>
            </div>

            <div className="stat-card">
              <h3 className="stat-label">Progress</h3>
              <p className="stat-value">{rankProgress.progress.toFixed(0)}%</p>
              <p className="text-sm text-muted-foreground mt-1">
                To next rank
              </p>
            </div>

            <div className="stat-card">
              <h3 className="stat-label">Tasks Today</h3>
              <p className="stat-value">{tasks.length}</p>
              <p className="text-sm text-muted-foreground mt-1">
                Pending tasks
              </p>
            </div>

            <div className="stat-card">
              <h3 className="stat-label">Streak</h3>
              <p className="stat-value">0</p>
              <p className="text-sm text-muted-foreground mt-1">
                Days in a row
              </p>
            </div>
          </div>

          {/* Pending Tasks */}
          {tasks.length > 0 ? (
            <>
              <h2 className="text-xl font-bold text-orbitron mb-4">Pending Tasks</h2>
              <div className="space-y-4">
                {tasks.map((task) => (
                  <div key={task.id} className="glass-panel p-5">
                    <div className="flex justify-between items-start">
                      <div>
                        <h3 className="font-bold text-orbitron">{task.title}</h3>
                        <p className="text-muted-foreground">{task.subject}</p>
                        <p className="mt-2 flex items-center gap-2">
                          <span className="w-3 h-3 bg-primary rounded"></span>
                          <span className="text-primary font-medium">+{task.xp_value} XP</span>
                        </p>
                      </div>
                      <button
                        onClick={() => {
                          setSelectedTask(task);
                          setOpenSubmissionModal(true);
                        }}
                        className="glowing-border px-4 py-2 text-primary font-medium hover:bg-primary/20 transition-all"
                      >
                        Submit Proof
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </>
          ) : (
            <div className="glass-panel text-center py-8">
              <p className="text-muted-foreground">
                No pending tasks. Create a new task to get started!
              </p>
              <button
                onClick={() => setOpenCreateTaskModal(true)}
                className="mt-4 glowing-border px-6 py-3 text-primary font-medium hover:bg-primary/20"
              >
                Create First Task
              </button>
            </div>
          )}

          {/* Recent Submissions */}
          {submissions.length > 0 ? (
            <>
              <h2 className="text-xl font-bold text-orbitron mb-4 mt-6">Recent Submissions</h2>
              <div className="space-y-4">
                {submissions.map((submission) => {
                  const taskInfo = submission.tasks?.[0];
                  const verdictClass =
                    submission.ai_verdict === 'approved' ? 'text-primary' :
                    submission.ai_verdict === 'rejected' ? 'text-destructive' :
                    'text-accent';

                  return (
                    <div key={submission.id} className="glass-panel p-5">
                      <div className="flex justify-between items-start">
                        <div>
                          <h3 className="font-bold text-orbitron">{taskInfo?.title ?? 'Task'}</h3>
                          <p className="text-muted-foreground mt-1">
                            {new Date(submission.submitted_at).toLocaleString()}
                          </p>
                          {submission.ai_verdict === 'approved' && (
                            <p className={`${verdictClass} font-medium mt-1 flex items-center gap-2`}>
                              <span className="w-3 h-3 bg-primary rounded"></span>
                              Verified +{taskInfo?.xp_value ?? 0} XP
                            </p>
                          )}
                          {submission.ai_verdict === 'rejected' && (
                            <p className={`${verdictClass} font-medium mt-1`}>
                              Rejected
                            </p>
                          )}
                          {submission.ai_verdict === 'pending' && (
                            <p className={`${verdictClass} font-medium mt-1 animate-pulse`}>
                              Pending Review
                            </p>
                          )}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </>
          ) : (
            <div className="glass-panel text-center py-8">
              <p className="text-muted-foreground">
                No submissions yet. Submit proof for your tasks to see them here!
              </p>
            </div>
          )}

          {/* Leaderboard */}
          {leaderboard.length > 0 ? (
            <>
              <h2 className="text-xl font-bold text-orbitron mb-4 mt-6">Leaderboard</h2>
              <div className="space-y-4">
                {leaderboard.map((user, index) => (
                  <div key={user.id} className="glass-panel p-5">
                    <div className="flex items-center space-x-4">
                      <div className="w-10 h-10 flex items-center justify-center bg-primary/20 text-primary rounded">
                        {index + 1}
                      </div>
                      <div>
                        <h3 className="font-bold text-orbitron">{user.name}</h3>
                        <p className="text-muted-foreground mt-1">
                          Rank:
                          <span className={`rank-badge rank-${user.rank?.toLowerCase() || 'e'} text-xs`}>
                            {user.rank}
                          </span>
                          • {formatNumber(user.total_xp)} XP
                        </p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </>
          ) : (
            <div className="glass-panel text-center py-8">
              <p className="text-muted-foreground">
                No data available yet. Start completing tasks to appear on the leaderboard!
              </p>
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex flex-col sm:flex-row sm:space-x-4 mt-6">
            <button
              onClick={() => {
                if (tasks.length === 0) {
                  alert('Please create a task first');
                  return;
                }
                setSelectedTask(tasks[0]);
                setOpenSubmissionModal(true);
              }}
              className="flex-1 glowing-border px-5 py-3 text-primary font-medium hover:bg-primary/20"
            >
              Submit Proof
            </button>
            <button
              onClick={() => {
                setOpenCreateTaskModal(true);
              }}
              className="flex-1 glowing-border px-5 py-3 text-accent font-medium hover:bg-accent/20"
            >
              Create Task
            </button>
            <button
              onClick={() => {
                router.push('/profile');
              }}
              className="flex-1 glowing-border px-5 py-3 text-secondary font-medium hover:bg-secondary/20"
            >
              Profile
            </button>
          </div>
        </div>
      </main>

      {/* Submission Modal */}
      {selectedTask && (
        <SubmissionModal
          isOpen={openSubmissionModal}
          onClose={() => {
            setOpenSubmissionModal(false);
            setSelectedTask(null);
          }}
          taskId={selectedTask.id}
          taskTitle={selectedTask.title}
          taskXpValue={selectedTask.xp_value}
        />
      )}

      {/* Create Task Modal */}
      <CreateTaskModal
        isOpen={openCreateTaskModal}
        onClose={() => {
          setOpenCreateTaskModal(false);
        }}
      />
    </div>
  );
}