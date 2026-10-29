'use client';

import * as React from 'react';
import { CheckCircle2, Clock, Upload, XCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Modal } from '@/components/ui/modal';
import { useToast } from '@/components/ui/toast';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/lib/auth-context';
import type { Task } from '@/lib/types';

interface SubmissionModalProps {
  isOpen: boolean;
  onClose: () => void;
  task: Task;
  /** Called after a submission completes so the parent can refetch. */
  onSubmitted?: () => void;
}

type Phase = 'idle' | 'uploading' | 'verifying' | 'done';

interface VerifyResult {
  status: 'approved' | 'rejected' | 'pending';
  message: string;
  xpAwarded?: number;
}

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

function sanitizeFileName(name: string): string {
  return name.replace(/[^a-zA-Z0-9._-]/g, '-').slice(-80) || 'proof.jpg';
}

export default function SubmissionModal({
  isOpen,
  onClose,
  task,
  onSubmitted,
}: SubmissionModalProps) {
  const { user } = useAuth();
  const { toast } = useToast();
  const [description, setDescription] = React.useState('');
  const [mode, setMode] = React.useState<'file' | 'url'>('file');
  const [file, setFile] = React.useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = React.useState<string | null>(null);
  const [photoUrl, setPhotoUrl] = React.useState('');
  const [phase, setPhase] = React.useState<Phase>('idle');
  const [result, setResult] = React.useState<VerifyResult | null>(null);
  const [error, setError] = React.useState<string | null>(null);

  // Revoke object URLs to avoid leaking memory across file picks.
  React.useEffect(() => {
    return () => {
      if (previewUrl) URL.revokeObjectURL(previewUrl);
    };
  }, [previewUrl]);

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const picked = event.target.files?.[0] ?? null;
    setError(null);
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setPreviewUrl(null);
    setFile(null);

    if (!picked) return;
    if (!picked.type.startsWith('image/')) {
      setError('Please choose an image file (photo of your work).');
      return;
    }
    if (picked.size > MAX_IMAGE_BYTES) {
      setError('Image is larger than 5 MB. Please use a smaller photo.');
      return;
    }
    setFile(picked);
    setPreviewUrl(URL.createObjectURL(picked));
  };

  /** Uploads the image (or passes through a URL) and returns the stored reference. */
  const resolvePhotoReference = async (): Promise<string> => {
    if (mode === 'url') {
      const trimmed = photoUrl.trim();
      let parsed: URL;
      try {
        parsed = new URL(trimmed);
      } catch {
        throw new Error('Please paste a valid image URL.');
      }
      if (!['http:', 'https:'].includes(parsed.protocol)) {
        throw new Error('Image URL must start with http:// or https://');
      }
      return trimmed;
    }

    if (!file || !user) throw new Error('Please choose a proof photo first.');
    const path = `${user.id}/${task.id}/${Date.now()}-${sanitizeFileName(file.name)}`;
    const { error: uploadError } = await supabase.storage
      .from('proofs')
      .upload(path, file, { contentType: file.type, upsert: false });
    if (uploadError) {
      throw new Error(
        `Upload failed: ${uploadError.message}. If the "proofs" bucket is missing, apply supabase migration 002 — or use the image-URL option instead.`,
      );
    }
    return path;
  };

  const insertSubmission = async (photoReference: string): Promise<string> => {
    const base = {
      task_id: task.id,
      photo_url: photoReference,
      ai_verdict: 'pending' as const,
    };

    // `description` arrives in migration 002; retry without it on older DBs.
    const withDescription = await supabase
      .from('submissions')
      .insert({ ...base, description: description.trim() || null })
      .select('id')
      .single();

    if (!withDescription.error) return withDescription.data.id as string;

    const looksLikeMissingColumn =
      withDescription.error.code === '42703' ||
      withDescription.error.message.toLowerCase().includes('description');
    if (!looksLikeMissingColumn) throw withDescription.error;

    const fallback = await supabase
      .from('submissions')
      .insert(base)
      .select('id')
      .single();
    if (fallback.error) throw fallback.error;
    return fallback.data.id as string;
  };

  const requestVerification = async (
    submissionId: string,
  ): Promise<VerifyResult> => {
    const {
      data: { session },
    } = await supabase.auth.getSession();
    if (!session) throw new Error('Your session expired. Sign in again.');

    const response = await fetch('/api/submissions/verify', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${session.access_token}`,
      },
      body: JSON.stringify({ submissionId }),
    });

    const payload = (await response.json().catch(() => null)) as {
      status?: VerifyResult['status'];
      message?: string;
      xpAwarded?: number;
      error?: string;
    } | null;

    if (!response.ok) {
      throw new Error(
        payload?.error ?? payload?.message ?? 'Verification request failed.',
      );
    }
    return {
      status: payload?.status ?? 'pending',
      message:
        payload?.message ?? 'Proof submitted. Awaiting System verification.',
      xpAwarded: payload?.xpAwarded,
    };
  };

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);
    setResult(null);

    if (!user) {
      setError('You must be signed in to submit proof.');
      return;
    }

    try {
      setPhase('uploading');
      const photoReference = await resolvePhotoReference();
      const submissionId = await insertSubmission(photoReference);

      setPhase('verifying');
      const verification = await requestVerification(submissionId);
      setResult(verification);
      setPhase('done');

      toast({
        title:
          verification.status === 'approved'
            ? 'Proof approved'
            : verification.status === 'rejected'
              ? 'Proof rejected'
              : 'Proof submitted',
        description: verification.message,
        variant:
          verification.status === 'approved'
            ? 'success'
            : verification.status === 'rejected'
              ? 'error'
              : 'warning',
      });
      onSubmitted?.();
    } catch (err) {
      setPhase('idle');
      setError(err instanceof Error ? err.message : 'Failed to submit proof');
    }
  };

  const busy = phase === 'uploading' || phase === 'verifying';

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={`Submit Proof — ${task.title}`}
      description={`Upload a photo of your completed work to earn +${task.xp_value} XP. The System verifies every submission.`}
    >
      {phase === 'done' && result ? (
        <div className="space-y-4 text-center">
          {result.status === 'approved' && (
            <CheckCircle2 className="mx-auto h-12 w-12 text-primary" aria-hidden />
          )}
          {result.status === 'rejected' && (
            <XCircle className="mx-auto h-12 w-12 text-red-400" aria-hidden />
          )}
          {result.status === 'pending' && (
            <Clock className="mx-auto h-12 w-12 text-yellow-300" aria-hidden />
          )}
          <p className="text-sm text-foreground">{result.message}</p>
          <Button onClick={onClose} className="w-full">
            Done
          </Button>
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="flex gap-2" role="tablist" aria-label="Proof source">
            <Button
              variant={mode === 'file' ? 'default' : 'outline'}
              size="sm"
              onClick={() => setMode('file')}
              disabled={busy}
            >
              <Upload className="h-4 w-4" aria-hidden /> Upload photo
            </Button>
            <Button
              variant={mode === 'url' ? 'default' : 'outline'}
              size="sm"
              onClick={() => setMode('url')}
              disabled={busy}
            >
              Paste image URL
            </Button>
          </div>

          {mode === 'file' ? (
            <div>
              <label
                htmlFor="proof-file"
                className="block text-sm font-medium text-foreground mb-1"
              >
                Proof photo (image, max 5 MB)
              </label>
              <Input
                id="proof-file"
                type="file"
                accept="image/*"
                onChange={handleFileChange}
                disabled={busy}
              />
              {previewUrl && (
                // Local object URL preview; next/image cannot optimize it.
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={previewUrl}
                  alt="Preview of your proof"
                  className="mt-3 max-h-56 w-full rounded-lg border border-border object-contain"
                />
              )}
            </div>
          ) : (
            <div>
              <label
                htmlFor="proof-url"
                className="block text-sm font-medium text-foreground mb-1"
              >
                Image URL
              </label>
              <Input
                id="proof-url"
                type="url"
                value={photoUrl}
                onChange={(event) => setPhotoUrl(event.target.value)}
                placeholder="https://…"
                disabled={busy}
              />
            </div>
          )}

          <div>
            <label
              htmlFor="proof-description"
              className="block text-sm font-medium text-foreground mb-1"
            >
              What did you do? (optional)
            </label>
            <textarea
              id="proof-description"
              value={description}
              onChange={(event) => setDescription(event.target.value)}
              rows={3}
              maxLength={500}
              placeholder="e.g. Solved 30 problems from HC Verma vol. 2, ch. 10"
              disabled={busy}
              className="flex w-full rounded-md border border-input bg-black/30 px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50"
            />
          </div>

          {phase === 'verifying' && (
            <p className="text-sm font-orbitron text-primary" role="status">
              [SYSTEM] Verifying your proof…
            </p>
          )}

          {error && (
            <div
              role="alert"
              className="rounded-md border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300"
            >
              {error}
            </div>
          )}

          <div className="flex justify-end gap-3 pt-2">
            <Button variant="outline" onClick={onClose} disabled={busy}>
              Cancel
            </Button>
            <Button
              type="submit"
              isLoading={busy}
              disabled={mode === 'file' ? !file : !photoUrl.trim()}
            >
              {phase === 'uploading'
                ? 'Uploading…'
                : phase === 'verifying'
                  ? 'Verifying…'
                  : 'Submit Proof'}
            </Button>
          </div>
        </form>
      )}
    </Modal>
  );
}
