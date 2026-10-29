import type { Rank } from './utils';

export interface Profile {
  id: string;
  name: string;
  rank: Rank;
  total_xp: number;
  /** Added in migration 002; may be absent on older databases. */
  current_streak?: number | null;
  last_active_date?: string | null;
  created_at: string;
  updated_at: string;
}

export type TaskStatus = 'pending' | 'approved' | 'rejected';

export interface Task {
  id: string;
  user_id: string;
  title: string;
  subject: string;
  xp_value: number;
  status: TaskStatus;
  created_at: string;
  updated_at: string;
}

export type AiVerdict = 'approved' | 'rejected' | 'pending';

export interface Submission {
  id: string;
  task_id: string;
  photo_url: string;
  ai_verdict: AiVerdict | null;
  /** Added in migration 002. */
  description?: string | null;
  ai_notes?: string | null;
  submitted_at: string;
  verified_at: string | null;
}

export interface SubmissionWithTask extends Submission {
  tasks: {
    title: string;
    xp_value: number;
  };
}

export interface LeaderboardEntry {
  id: string;
  name: string;
  total_xp: number;
  rank: Rank;
  current_streak?: number | null;
}

export interface XpLogEntry {
  id: string;
  user_id: string;
  xp_change: number;
  reason: string;
  created_at: string;
}
