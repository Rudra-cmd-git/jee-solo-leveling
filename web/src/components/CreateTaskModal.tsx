'use client';

import * as React from 'react';
import { Button } from '@/components/ui/button';
import { ModalContent, ModalHeader, ModalTitle, ModalDescription } from '@/components/ui/modal';
import { supabase } from '@/lib/supabase';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth-context';

interface CreateTaskModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function CreateTaskModal({
  isOpen,
  onClose,
}: CreateTaskModalProps) {
  const { user } = useAuth();
  const [title, setTitle] = React.useState('');
  const [subject, setSubject] = React.useState('');
  const [xpValue, setXpValue] = React.useState(10);
  const [isLoading, setIsLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const router = useRouter();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    if (!user) {
      setError('User not authenticated');
      setIsLoading(false);
      return;
    }

    try {
      // Get the current session to retrieve the access token
      const {
        data: { session },
      } = await supabase.auth.getSession();

      if (!session?.access_token) {
        setError('Failed to get authentication token');
        setIsLoading(false);
        return;
      }

      // Call the backend API instead of direct Supabase insert
      const response = await fetch('/api/tasks', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({
          title,
          subject,
          xpValue: parseInt(xpValue.toString()),
        }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to create task');
      }

      // Close modal and refresh tasks
      onClose();
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create task');
    } finally {
      setIsLoading(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
      <div className="relative w-full max-w-md max-h-[90vh] overflow-y-auto">
        <div className="glass-panel p-6">
          <ModalContent className="pb-0">
            <ModalHeader className="mb-4">
              <ModalTitle className="text-2xl font-bold text-orbitron">
                Create New Task
              </ModalTitle>
              <ModalDescription className="text-muted-foreground">
                Define a study task to earn XP upon completion
              </ModalDescription>
            </ModalHeader>
            <form onSubmit={handleSubmit} className="space-y-5">
              <div className="space-y-2">
                <label htmlFor="title" className="text-muted-foreground font-medium">
                  Task Title
                </label>
                <input
                  id="title"
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  required
                  className="w-full px-4 py-3 bg-secondary-card/50 border border-muted-foreground/20 rounded-md focus:ring-2 focus:ring-primary/30 focus:border-primary/50 text-muted-foreground"
                />
              </div>

              <div className="space-y-2">
                <label htmlFor="subject" className="text-muted-foreground font-medium">
                  Subject
                </label>
                <input
                  id="subject"
                  type="text"
                  value={subject}
                  onChange={(e) => setSubject(e.target.value)}
                  required
                  className="w-full px-4 py-3 bg-secondary-card/50 border border-muted-foreground/20 rounded-md focus:ring-2 focus:ring-primary/30 focus:border-primary/50 text-muted-foreground"
                />
              </div>

              <div className="space-y-2">
                <label htmlFor="xpValue" className="text-muted-foreground font-medium">
                  XP Value
                </label>
                <input
                  id="xpValue"
                  type="number"
                  value={xpValue}
                  onChange={(e) => setXpValue(parseInt(e.target.value) || 10)}
                  min="1"
                  className="w-full px-4 py-3 bg-secondary-card/50 border border-muted-foreground/20 rounded-md focus:ring-2 focus:ring-primary/30 focus:border-primary/50 text-muted-foreground"
                />
              </div>

              {error && (
                <div className="bg-destructive/20 border border-destructive/30 text-destructive px-4 py-3 rounded-lg">
                  {error}
                </div>
              )}

              <div className="flex justify-end space-x-3">
                <Button
                  variant="outline"
                  onClick={onClose}
                  className="px-5 py-2.5 text-muted-foreground/50 border border-muted-foreground/30"
                >
                  Cancel
                </Button>
                <Button
                  onClick={handleSubmit}
                  isLoading={isLoading}
                  className="glowing-border px-5 py-3 text-primary font-medium hover:bg-primary/20"
                >
                  Create Task
                </Button>
              </div>
            </form>
          </ModalContent>
        </div>
      </div>
    </div>
  );
}