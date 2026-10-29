'use client';

import * as React from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Modal } from '@/components/ui/modal';
import { useToast } from '@/components/ui/toast';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/lib/auth-context';
import { MAX_TASK_XP } from '@/lib/utils';

interface CreateTaskModalProps {
  isOpen: boolean;
  onClose: () => void;
  /** Called after a task is created so the parent can refetch its list. */
  onCreated?: () => void;
}

const SUBJECTS = ['Physics', 'Chemistry', 'Maths', 'Biology', 'Other'] as const;

const DIFFICULTY_PRESETS = [
  { label: 'Easy', xp: 50 },
  { label: 'Medium', xp: 100 },
  { label: 'Hard', xp: 200 },
  { label: 'Boss', xp: 400 },
] as const;

const selectClassName =
  'flex h-10 w-full rounded-md border border-input bg-black/30 px-3 py-2 text-sm text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background disabled:cursor-not-allowed disabled:opacity-50';

export default function CreateTaskModal({
  isOpen,
  onClose,
  onCreated,
}: CreateTaskModalProps) {
  const { user } = useAuth();
  const { toast } = useToast();
  const [title, setTitle] = React.useState('');
  const [subject, setSubject] = React.useState<string>(SUBJECTS[0]);
  const [xpValue, setXpValue] = React.useState<number>(100);
  const [isLoading, setIsLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  const resetForm = () => {
    setTitle('');
    setSubject(SUBJECTS[0]);
    setXpValue(100);
    setError(null);
  };

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);

    if (!user) {
      setError('You must be signed in to create a quest.');
      return;
    }
    if (!Number.isFinite(xpValue) || xpValue < 1 || xpValue > MAX_TASK_XP) {
      setError(`XP value must be between 1 and ${MAX_TASK_XP}.`);
      return;
    }

    setIsLoading(true);
    try {
      const { error: insertError } = await supabase.from('tasks').insert({
        user_id: user.id,
        title: title.trim(),
        subject,
        xp_value: Math.round(xpValue),
        status: 'pending',
      });
      if (insertError) throw insertError;

      toast({
        title: 'Quest created',
        description: `"${title.trim()}" is worth ${Math.round(xpValue)} XP.`,
        variant: 'success',
      });
      resetForm();
      onCreated?.();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create quest');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Create Quest"
      description="Define a study task. Submit photo proof later to earn its XP."
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label
            htmlFor="quest-title"
            className="block text-sm font-medium text-foreground mb-1"
          >
            Quest title
          </label>
          <Input
            id="quest-title"
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            placeholder="e.g. Solve 30 rotational mechanics problems"
            required
            maxLength={120}
            disabled={isLoading}
          />
        </div>

        <div>
          <label
            htmlFor="quest-subject"
            className="block text-sm font-medium text-foreground mb-1"
          >
            Subject
          </label>
          <select
            id="quest-subject"
            value={subject}
            onChange={(event) => setSubject(event.target.value)}
            className={selectClassName}
            disabled={isLoading}
          >
            {SUBJECTS.map((item) => (
              <option key={item} value={item} className="bg-card">
                {item}
              </option>
            ))}
          </select>
        </div>

        <div>
          <span className="block text-sm font-medium text-foreground mb-1">
            Difficulty
          </span>
          <div className="flex flex-wrap gap-2">
            {DIFFICULTY_PRESETS.map((preset) => (
              <Button
                key={preset.label}
                variant={xpValue === preset.xp ? 'default' : 'outline'}
                size="sm"
                onClick={() => setXpValue(preset.xp)}
                disabled={isLoading}
              >
                {preset.label} · {preset.xp} XP
              </Button>
            ))}
          </div>
        </div>

        <div>
          <label
            htmlFor="quest-xp"
            className="block text-sm font-medium text-foreground mb-1"
          >
            XP value (1–{MAX_TASK_XP})
          </label>
          <Input
            id="quest-xp"
            type="number"
            min={1}
            max={MAX_TASK_XP}
            value={xpValue}
            onChange={(event) =>
              setXpValue(Number.parseInt(event.target.value, 10) || 0)
            }
            required
            disabled={isLoading}
          />
          <p className="text-xs text-muted-foreground mt-1">
            Capped by the System so the leaderboard stays honest.
          </p>
        </div>

        {error && (
          <div
            role="alert"
            className="rounded-md border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300"
          >
            {error}
          </div>
        )}

        <div className="flex justify-end gap-3 pt-2">
          <Button variant="outline" onClick={onClose} disabled={isLoading}>
            Cancel
          </Button>
          <Button type="submit" isLoading={isLoading}>
            Create Quest
          </Button>
        </div>
      </form>
    </Modal>
  );
}
