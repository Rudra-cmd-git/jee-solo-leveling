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
  const [verifying, setVerifying] = React.useState(false);
  const [verificationResult, setVerificationResult] = React.useState<{
    verdict: string;
    confidence: number;
    reasoning: string;
  } | null>(null);
  const [error, setError] = React.useState<string | null>(null);
  const router = useRouter();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    try {
      // Create submission record
      const { data: submissionData, error: supabaseError } = await supabase
        .from('submissions')
        .insert({
          task_id: taskId,
          photo_url: photoUrl || 'https://example.com/placeholder.jpg',
          ai_verdict: 'pending',
        })
        .select()
        .single();

      if (supabaseError) throw supabaseError;

      if (!submissionData) {
        throw new Error('Failed to create submission');
      }

      // Start verification process
      setVerifying(true);
      setIsLoading(false);

      try {
        // Call our verification API
        const verificationResponse = await fetch(
          new URL('/api/verify-submission', window.location.origin),
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              submissionId: submissionData.id,
              photoUrl: submissionData.photo_url,
            }),
          }
        );

        if (!verificationResponse.ok) {
          throw new Error(`Verification failed: ${verificationResponse.statusText}`);
        }

        const verificationData = await verificationResponse.json();
        setVerificationResult(verificationData);

        // Update submission with verification results
        const { error: updateError } = await supabase
          .from('submissions')
          .update({
            ai_verdict: verificationData.verdict,
            verified_at: new Date().toISOString(),
          })
          .eq('id', submissionData.id);

        if (updateError) throw updateError;

        // If approved, award XP via server-side route
        if (verificationData.verdict === 'approved') {
          try {
            const { data: { session } } = await supabase.auth.getSession();

            if (!session?.access_token) {
              throw new Error('No active session');
            }

            const xpResponse = await fetch('/api/award-xp', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${session.access_token}`,
              },
              body: JSON.stringify({
                xpChange: taskXpValue,
                reason: `Completed task: ${taskTitle}`,
              }),
            });

            if (!xpResponse.ok) {
              const errorData = await xpResponse.json();
              console.warn('XP award failed:', errorData.error);
              // Don't fail the submission if XP award fails
            } else {
              const successData = await xpResponse.json();
              console.log('XP awarded successfully:', successData);
            }
          } catch (xpError) {
            console.warn('XP award error:', xpError);
            // Don't fail the submission if XP award fails
          }
        }

      } catch (verifyError) {
        console.error('Verification error:', verifyError);
        // Even if verification fails, we keep the submission as pending
        // User can retry verification later
        setVerificationResult({
          verdict: 'pending',
          confidence: 0,
          reasoning: 'Verification service unavailable',
        });
      }
    } catch (err: any) {
      setError(err.message || 'Failed to submit proof');
    } finally {
      setIsLoading(false);
      setVerifying(false);
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

              {verificationResult && (
                <div className="bg-blue-50 border border-blue-200 text-blue-800 px-4 py-3 rounded">
                  <div className="flex items-center space-x-3">
                    <div className="w-5 h-5">
                      {verificationResult.verdict === 'approved' && (
                        <svg className="fill-current" viewBox="0 0 20 20">
                          <path d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 9.172l3.742 3.742 1.447-1.415a1 1 0 011.414 0l2.06 2.06a1 1 0 01-1.414 1.414l-1.415-1.447-3.742-3.742a1 1 0 01-1.414-1.414z" />
                        </svg>
                      )}
                      {verificationResult.verdict === 'rejected' && (
                        <svg className="fill-current" viewBox="0 0 20 20">
                          <path d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z" />
                        </svg>
                      )}
                      {verificationResult.verdict === 'pending' && (
                        <svg className="fill-current" viewBox="0 0 20 20">
                          <path d="M10 18a8 8 0 100-16 8 8 0 000 16zm.93-4.707l1.414 1.414a1 1 0 001.414-1.414l1.414-1.414a1 1 0 00-1.414-1.414L12.343 9.293 13.757 7.879a1 1 0 00-1.414-1.414l-1.414 1.414L10.93 11.293 9.516 9.879a1 1 0 00-1.414 1.414l1.414 1.414z" />
                        </svg>
                      )}
                    </div>
                    <div>
                      <p className="font-medium">
                        Verification: {verificationResult.verdict.charAt(0).toUpperCase() + verificationResult.verdict.slice(1)}
                      </p>
                      <p className="text-sm text-gray-500">
                        Confidence: {(verificationResult.confidence * 100).toFixed(0)}%
                      </p>
                      <p className="text-sm text-gray-500 mt-1">
                        {verificationResult.reasoning}
                      </p>
                    </div>
                  </div>
                </div>
              )}

              <div className="flex justify-end space-x-3">
                {verifying ? (
                  <Button
                    variant="outline"
                    onClick={onClose}
                    size="sm"
                  >
                    Closing...
                  </Button>
                ) : (
                  <Button
                    variant="outline"
                    onClick={onClose}
                    size="sm"
                  >
                    Close
                  </Button>
                )}
                {!verifying && !isLoading && (
                  <Button
                    onClick={handleSubmit}
                    isLoading={isLoading}
                    size="sm"
                  >
                    {isLoading ? 'Submitting...' : 'Submit Proof'}
                  </Button>
                )}
              </div>
            </form>
          </ModalContent>
        </div>
      </div>
    </div>
  );
}