import { NextResponse } from 'next/server';
import {
  getSupabaseAdmin,
  getSupabaseAnonServer,
} from '@/lib/supabase-admin';

export const runtime = 'nodejs';
export const maxDuration = 60;

/**
 * POST /api/submissions/verify  { submissionId }
 *
 * Verifies a proof submission with Claude Vision and, on approval, awards
 * XP through the service-role-only public.award_xp() function.
 *
 * Auth: caller's Supabase access token as `Authorization: Bearer <token>`.
 * Degrades gracefully: when SUPABASE_SERVICE_ROLE_KEY or ANTHROPIC_API_KEY
 * is missing the submission simply stays `pending` and the response says
 * so — the client never crashes because the server is half-configured.
 */

interface SubmissionRow {
  id: string;
  task_id: string;
  photo_url: string;
  ai_verdict: 'approved' | 'rejected' | 'pending' | null;
  tasks: {
    title: string;
    subject: string;
    xp_value: number;
    user_id: string;
    status: string;
  };
}

interface ClaudeVerdict {
  verdict: 'approved' | 'rejected';
  confidence: number;
  reason: string;
}

const SUPPORTED_MEDIA_TYPES = [
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
] as const;

function pendingResponse(message: string) {
  return NextResponse.json({ status: 'pending', message });
}

function errorResponse(status: number, error: string) {
  return NextResponse.json({ error }, { status });
}

async function loadImageBytes(
  photoUrl: string,
  admin: NonNullable<ReturnType<typeof getSupabaseAdmin>>,
): Promise<{ base64: string; mediaType: string }> {
  let bytes: ArrayBuffer;
  let mediaType = 'image/jpeg';

  if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
    const response = await fetch(photoUrl, {
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) {
      throw new Error(`Could not download proof image (HTTP ${response.status}).`);
    }
    mediaType = response.headers.get('content-type')?.split(';')[0] ?? mediaType;
    bytes = await response.arrayBuffer();
  } else {
    // Storage object path inside the private `proofs` bucket.
    const { data, error } = await admin.storage.from('proofs').download(photoUrl);
    if (error || !data) {
      throw new Error(`Could not download proof from storage: ${error?.message ?? 'unknown error'}`);
    }
    if (data.type) mediaType = data.type;
    bytes = await data.arrayBuffer();
  }

  if (bytes.byteLength > 8 * 1024 * 1024) {
    throw new Error('Proof image is too large to verify (max 8 MB).');
  }
  if (!SUPPORTED_MEDIA_TYPES.includes(mediaType as (typeof SUPPORTED_MEDIA_TYPES)[number])) {
    mediaType = 'image/jpeg';
  }

  return {
    base64: Buffer.from(bytes).toString('base64'),
    mediaType,
  };
}

async function askClaude(
  image: { base64: string; mediaType: string },
  task: { title: string; subject: string },
): Promise<ClaudeVerdict> {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  const model = process.env.ANTHROPIC_MODEL ?? 'claude-sonnet-4-5';

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey ?? '',
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model,
      max_tokens: 512,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'image',
              source: {
                type: 'base64',
                media_type: image.mediaType,
                data: image.base64,
              },
            },
            {
              type: 'text',
              text: [
                'You are the verification System for a JEE (Indian engineering entrance) study app.',
                `A student claims they completed this study task: "${task.title}" (subject: ${task.subject}).`,
                'The image is their proof of work (e.g. handwritten solutions, notebook pages, worked problems).',
                'Approve only if the image plausibly shows genuine study work related to the task.',
                'Reject blank pages, unrelated images, screenshots unrelated to studying, or photos with no visible work.',
                'Respond with ONLY a JSON object, no other text:',
                '{"verdict":"approved" or "rejected","confidence":0.0 to 1.0,"reason":"one short sentence"}',
              ].join('\n'),
            },
          ],
        },
      ],
    }),
    signal: AbortSignal.timeout(45_000),
  });

  if (!response.ok) {
    const detail = await response.text().catch(() => '');
    throw new Error(`Claude API error ${response.status}: ${detail.slice(0, 200)}`);
  }

  const payload = (await response.json()) as {
    content?: Array<{ type: string; text?: string }>;
  };
  const text = payload.content?.find((block) => block.type === 'text')?.text ?? '';
  const jsonMatch = text.match(/\{[\s\S]*\}/);
  if (!jsonMatch) throw new Error('Claude did not return a JSON verdict.');

  const parsed = JSON.parse(jsonMatch[0]) as Partial<ClaudeVerdict>;
  return {
    verdict: parsed.verdict === 'approved' ? 'approved' : 'rejected',
    confidence:
      typeof parsed.confidence === 'number'
        ? Math.min(1, Math.max(0, parsed.confidence))
        : 0,
    reason:
      typeof parsed.reason === 'string' && parsed.reason.trim()
        ? parsed.reason.trim().slice(0, 500)
        : 'No reason given.',
  };
}

export async function POST(request: Request) {
  const admin = getSupabaseAdmin();
  const anon = getSupabaseAnonServer();

  if (!admin || !anon) {
    return pendingResponse(
      'Proof received. Automated verification is not configured on the server yet (missing service-role key), so it stays pending. See SUPABASE_SETUP.md.',
    );
  }

  // --- Auth: the submission must belong to the caller. ---
  const authHeader = request.headers.get('authorization') ?? '';
  const token = authHeader.toLowerCase().startsWith('bearer ')
    ? authHeader.slice(7)
    : null;
  if (!token) return errorResponse(401, 'Missing authorization token.');

  const {
    data: { user },
    error: userError,
  } = await anon.auth.getUser(token);
  if (userError || !user) return errorResponse(401, 'Invalid or expired session.');

  const body = (await request.json().catch(() => null)) as {
    submissionId?: unknown;
  } | null;
  if (!body || typeof body.submissionId !== 'string') {
    return errorResponse(400, 'Request body must include { submissionId }.');
  }

  const { data: submissionData, error: loadError } = await admin
    .from('submissions')
    .select('*, tasks!inner (title, subject, xp_value, user_id, status)')
    .eq('id', body.submissionId)
    .single();

  if (loadError || !submissionData) {
    return errorResponse(404, 'Submission not found.');
  }
  const submission = submissionData as unknown as SubmissionRow;

  if (submission.tasks.user_id !== user.id) {
    return errorResponse(403, 'This submission does not belong to you.');
  }

  // Idempotent: never verify (or award XP) twice.
  if (submission.ai_verdict === 'approved' || submission.ai_verdict === 'rejected') {
    return NextResponse.json({
      status: submission.ai_verdict,
      message: 'This proof was already verified.',
    });
  }
  if (submission.tasks.status === 'approved') {
    return pendingResponse('This quest is already completed — XP was awarded for an earlier proof.');
  }

  if (!process.env.ANTHROPIC_API_KEY) {
    return pendingResponse(
      'Proof received. AI verification is not configured on the server yet (missing ANTHROPIC_API_KEY), so it stays pending.',
    );
  }

  let verdict: ClaudeVerdict;
  try {
    const image = await loadImageBytes(submission.photo_url, admin);
    verdict = await askClaude(image, submission.tasks);
  } catch (error) {
    console.error('[verify] verification failed:', error);
    return pendingResponse(
      'The System could not verify your proof right now. It stays pending — please try again later.',
    );
  }

  const approved = verdict.verdict === 'approved' && verdict.confidence >= 0.5;
  const now = new Date().toISOString();

  // Persist the verdict. `ai_notes` arrives in migration 002; fall back if absent.
  const verdictUpdate = {
    ai_verdict: approved ? 'approved' : 'rejected',
    verified_at: now,
    ai_notes: `${verdict.reason} (confidence ${(verdict.confidence * 100).toFixed(0)}%)`,
  };
  const { error: verdictError } = await admin
    .from('submissions')
    .update(verdictUpdate)
    .eq('id', submission.id);
  if (verdictError) {
    const { error: fallbackError } = await admin
      .from('submissions')
      .update({
        ai_verdict: verdictUpdate.ai_verdict,
        verified_at: verdictUpdate.verified_at,
      })
      .eq('id', submission.id);
    if (fallbackError) {
      console.error('[verify] could not save verdict:', fallbackError);
      return errorResponse(500, 'Verified, but saving the verdict failed.');
    }
  }

  if (!approved) {
    return NextResponse.json({
      status: 'rejected',
      message: `Proof rejected: ${verdict.reason} You can submit new proof for this quest.`,
    });
  }

  // Award XP via the locked-down ledger function, then close the quest.
  const { error: awardError } = await admin.rpc('award_xp', {
    p_user_id: user.id,
    p_xp_change: submission.tasks.xp_value,
    p_reason: `Quest approved: ${submission.tasks.title}`,
  });
  if (awardError) {
    console.error('[verify] award_xp failed:', awardError);
    return errorResponse(500, 'Proof approved, but awarding XP failed.');
  }

  await admin
    .from('tasks')
    .update({ status: 'approved' })
    .eq('id', submission.task_id);

  return NextResponse.json({
    status: 'approved',
    xpAwarded: submission.tasks.xp_value,
    message: `Proof approved! +${submission.tasks.xp_value} XP. ${verdict.reason}`,
  });
}
