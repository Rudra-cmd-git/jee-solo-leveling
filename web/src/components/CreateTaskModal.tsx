'use client';

import * as React from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { ModalContent, ModalFooter, ModalHeader, ModalTitle, ModalDescription } from '@/components/ui/modal';
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
    } catch (err: any) {
      setError(err.message || 'Failed to create task');
    } finally {
      setIsLoading(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
      <div className="relative w-full max-w-md max-h-[90vh] overflow-y-auto">
        <div className="bg-white rounded-lg p-6 shadow-lg">
          <ModalContent>
            <ModalHeader>
              <ModalTitle>Create New Task</ModalTitle>
              <ModalDescription>
                Define a study task to earn XP upon completion
              </ModalDescription>
            </ModalHeader>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label htmlFor="title" className="block text-sm font-medium text-gray-700 mb-1">
                  Task Title
                </label>
                <input
                  id="title"
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  required
                  className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
              </div>

              <div>
                <label htmlFor="subject" className="block text-sm font-medium text-gray-700 mb-1">
                  Subject
                </label>
                <input
                  id="subject"
                  type="text"
                  value={subject}
                  onChange={(e) => setSubject(e.target.value)}
                  required
                  className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
              </div>

              <div>
                <label htmlFor="xpValue" className="block text-sm font-medium text-gray-700 mb-1">
                  XP Value
                </label>
                <input
                  id="xpValue"
                  type="number"
                  value={xpValue}
                  onChange={(e) => setXpValue(parseInt(e.target.value) || 10)}
                  min="1"
                  className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
              </div>

              {error && (
                <div className="bg-red-50 border border-red-200 text-red-500 px-4 py-3 rounded">
                  {error}
                </div>
              )}

              <div className="flex justify-end space-x-3">
                <Button
                  variant="outline"
                  onClick={onClose}
                  size="sm"
                >
                  Cancel
                </Button>
                <Button
                  onClick={handleSubmit}
                  isLoading={isLoading}
                  size="sm"
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