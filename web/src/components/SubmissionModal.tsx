'use client';

import * as React from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { ModalContent, ModalFooter, ModalHeader, ModalTitle, ModalDescription } from '@/components/ui/modal';
import { supabase } from '@/lib/supabase';
import { useRouter } from 'next/navigation';

interface SubmissionModalProps {
  isOpen: boolean;
  onClose: () => void;
  taskId: string;
  taskTitle: string;
  taskXpValue: number;
}

export default function SubmissionModal({
  isOpen,
  onClose,
  taskId,
  taskTitle,
  taskXpValue,
}: SubmissionModalProps) {
  const [description, setDescription] = React.useState('');
  const [photoUrl, setPhotoUrl] = React.useState('');
  const [isLoading, setIsLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const router = useRouter();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    try {
      // For now, we'll just create a submission record
      // In a full implementation, you'd upload the photo to storage first
      const { data, error: supabaseError } = await supabase
        .from('submissions')
        .insert({
          task_id: taskId,
          photo_url: photoUrl || 'https://example.com/placeholder.jpg', // Placeholder
          ai_verdict: 'pending',
        });

      if (supabaseError) throw supabaseError;

      // Close modal and refresh submissions
      onClose();
      // In a real app, you might want to refetch submissions here
      // or use a callback prop to notify the parent
      router.refresh();
    } catch (err: any) {
      setError(err.message || 'Failed to submit proof');
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
              <ModalTitle>Submit Proof for {taskTitle}</ModalTitle>
              <ModalDescription>
                Describe your work and upload proof to earn +{taskXpValue} XP
              </ModalDescription>
            </ModalHeader>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-1">
                  Description
                </label>
                <textarea
                  id="description"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  rows={4}
                  className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
              </div>

              <div>
                <label htmlFor="photoUrl" className="block text-sm font-medium text-gray-700 mb-1">
                  Proof URL (Image Link)
                </label>
                <input
                  id="photoUrl"
                  type="text"
                  value={photoUrl}
                  onChange={(e) => setPhotoUrl(e.target.value)}
                  placeholder="Paste image URL here..."
                  className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
                <p className="text-xs text-gray-500 mt-1">
                  In a full implementation, this would be a file upload to storage
                </p>
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
                  Submit Proof
                </Button>
              </div>
            </form>
          </ModalContent>
        </div>
      </div>
    </div>
  );
}