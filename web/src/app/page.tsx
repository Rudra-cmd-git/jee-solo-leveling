'use client';

import { useEffect, useState } from 'react';
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

export default function DashboardPage() {
  const { user, loading } = useAuth();
  const router = useRouter();
  const [profile, setProfile] = useState<any>(null);
  const [tasks, setTasks] = useState<Task[]>([]);
  const [submissions, setSubmissions] = useState<SubmissionRow[]>([]);
  const [leaderboard, setLeaderboard] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [openSubmissionModal, setOpenSubmissionModal] = useState(false);
  const [selectedTask, setSelectedTask] = useState<Task | null>(null);
  const [openCreateTaskModal, setOpenCreateTaskModal] = useState(false);

  // Fetch user profile from public.users table
  useEffect(() => {
    if (!loading && !user) {
      router.replace('/sign-in');
      return;
    }

    if (user) {
      setIsLoading(true);

      void (async () => {
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
      setProfile(null);
      setTasks([]);
      setSubmissions([]);
      setLeaderboard([]);
      setIsLoading(false);
    }
  }, [user, loading, router]);

  const fetchProfile = async () => {
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
  };

  const fetchTasks = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('tasks')
        .select('*')
        .eq('user_id', user.id)
        .eq('status', 'pending')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setTasks((data ?? []) as Task[]);
    } catch (error) {
      console.error('Error fetching tasks:', error);
    }
  };

  const fetchSubmissions = async () => {
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
  };

  const fetchLeaderboard = async () => {
    try {
      const { data, error } = await supabase
        .from('users')
        .select('id, name, total_xp, rank')
        .order('total_xp', { ascending: false })
        .limit(10);

      if (error) throw error;
      setLeaderboard(data);
    } catch (error) {
      console.error('Error fetching leaderboard:', error);
    }
  };

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
            <div className="w-12 h-12 bg-gray-200 rounded-full flex items-center justify-center text-gray-500">
              {profile?.name?.charAt(0) ?? 'U'}
            </div>
            <div>
              <h1 className="text-2xl font-bold">
                Welcome back, {profile?.name || 'Studier'}!
              </h1>
              <p className="text-gray-600">
                Rank: {profile?.rank || 'E'} • XP: {formatNumber(profile?.total_xp || 0)}
              </p>
            </div>
          </div>

          {/* Stats */}
          <div className="flex flex-col sm:flex-row sm:space-x-4 mb-6">
            <div className="flex-1 bg-gray-50 p-4 rounded-lg">
              <h3 className="font-medium text-gray-500">Next Rank</h3>
              <p className="text-xl font-bold">{rankProgress.nextRank ?? 'MAX'}</p>
              <p className="text-sm text-gray-500 mt-1">
                {rankProgress.xpToNextRank > 0
                  ? `${formatNumber(rankProgress.xpToNextRank)} XP to go`
                  : 'Maximum rank achieved!'}
              </p>
            </div>

            <div className="flex-1 bg-gray-50 p-4 rounded-lg">
              <h3 className="font-medium text-gray-500">Progress</h3>
              <p className="text-xl font-bold">{rankProgress.progress.toFixed(0)}%</p>
              <p className="text-sm text-gray-500 mt-1">
                To next rank
              </p>
            </div>

            <div className="flex-1 bg-gray-50 p-4 rounded-lg">
              <h3 className="font-medium text-gray-500">Tasks Today</h3>
              <p className="text-xl font-bold">{tasks.length}</p>
              <p className="text-sm text-gray-500 mt-1">
                Pending tasks
              </p>
            </div>

            <div className="flex-1 bg-gray-50 p-4 rounded-lg">
              <h3 className="font-medium text-gray-500">Streak</h3>
              <p className="text-xl font-bold">0</p>
              <p className="text-sm text-gray-500 mt-1">
                Days in a row
              </p>
            </div>
          </div>

          {/* Pending Tasks */}
          {tasks.length > 0 ? (
            <>
              <h2 className="text-xl font-bold mb-4">Pending Tasks</h2>
              <div className="space-y-3">
                {tasks.map((task) => (
                  <div key={task.id} className="p-4 bg-gray-50 rounded-lg">
                    <div className="flex justify-between items-start">
                      <div>
                        <h3 className="font-bold">{task.title}</h3>
                        <p className="text-gray-600">{task.subject}</p>
                        <p className="text-green-600 font-medium mt-1">
                          +{task.xp_value} XP
                        </p>
                      </div>
                      <button
                        onClick={() => {
                          setSelectedTask(task);
                          setOpenSubmissionModal(true);
                        }}
                        className="px-3 py-1 bg-blue-500 text-white rounded hover:bg-blue-600"
                      >
                        Submit Proof
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </>
          ) : (
            <div className="text-center py-8 bg-gray-50 rounded-lg">
              <p className="text-gray-500">No pending tasks. Create a new task to get started!</p>
            </div>
          )}

          {/* Recent Submissions */}
          {submissions.length > 0 ? (
            <>
              <h2 className="text-xl font-bold mb-4 mt-6">Recent Submissions</h2>
              <div className="space-y-3">
                {submissions.map((submission) => {
                  const taskInfo = submission.tasks?.[0];

                  return (
                    <div key={submission.id} className="p-4 bg-gray-50 rounded-lg">
                      <div className="flex justify-between items-start">
                        <div>
                          <h3 className="font-bold">{taskInfo?.title ?? 'Task'}</h3>
                          <p className="text-gray-600 mt-1">
                            {new Date(submission.submitted_at).toLocaleDateString()}
                          </p>
                          {submission.ai_verdict === 'approved' && (
                            <p className="text-green-600 font-medium mt-1">
                              Verified +{taskInfo?.xp_value ?? 0} XP
                            </p>
                          )}
                          {submission.ai_verdict === 'rejected' && (
                            <p className="text-red-600 font-medium mt-1">
                              Rejected
                            </p>
                          )}
                          {submission.ai_verdict === 'pending' && (
                            <p className="text-yellow-600 font-medium mt-1">
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
            <div className="text-center py-8 bg-gray-50 rounded-lg mt-6">
              <p className="text-gray-500">No submissions yet. Submit proof for your tasks to see them here!</p>
            </div>
          )}

          {/* Leaderboard */}
          {leaderboard.length > 0 ? (
            <>
              <h2 className="text-xl font-bold mb-4 mt-6">Leaderboard</h2>
              <div className="space-y-3">
                {leaderboard.map((user, index) => (
                  <div key={user.id} className="p-4 bg-gray-50 rounded-lg">
                    <div className="flex items-center space-x-3">
                      <div className="w-8 h-8 bg-gray-200 rounded-flex items-center justify-center text-sm font-medium">
                        {index + 1}
                      </div>
                      <div>
                        <h3 className="font-bold">{user.name}</h3>
                        <p className="text-sm text-gray-500 mt-1">
                          Rank: {user.rank} • {formatNumber(user.total_xp)} XP
                        </p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </>
          ) : (
            <div className="text-center py-8 bg-gray-50 rounded-lg mt-6">
              <p className="text-gray-500">No data available yet. Start completing tasks to appear on the leaderboard!</p>
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex flex-col sm:flex-row sm:space-x-4 mt-6">
            <button
              onClick={() => {
                // For the general submit button, we could either:
                // 1. Open a modal to select a task first, or
                // 2. If there's only one task, use that
                // For now, let's use the first task if available, or show an alert
                if (tasks.length === 0) {
                  alert('Please create a task first');
                  return;
                }
                setSelectedTask(tasks[0]);
                setOpenSubmissionModal(true);
              }}
              className="flex-1 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            >
              Submit Proof
            </button>
            <button
              onClick={() => {
                setOpenCreateTaskModal(true);
              }}
              className="flex-1 px-4 py-2 bg-gray-200 text-gray-800 rounded hover:bg-gray-300"
            >
              Create Task
            </button>
            <button
              onClick={() => {
                router.push('/profile');
              }}
              className="flex-1 px-4 py-2 bg-gray-200 text-gray-800 rounded hover:bg-gray-300"
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