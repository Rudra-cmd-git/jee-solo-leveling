import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { createClient } from '@supabase/supabase-js';

// Helper function to get Supabase client (checked at runtime, not build time)
function getSupabaseClient() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseServiceRoleKey) {
    throw new Error('Missing Supabase environment variables: NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
  }

  return createClient(supabaseUrl, supabaseServiceRoleKey);
}

interface AwardXPRequest {
  xpChange: number;
  reason: string;
}

export async function POST(request: NextRequest) {
  try {
    // Get Supabase client at runtime
    const supabase = getSupabaseClient();

    // 1. Extract and validate request body
    const body: AwardXPRequest = await request.json();
    const { xpChange, reason } = body;

    // Validate inputs
    if (!xpChange || typeof xpChange !== 'number') {
      return NextResponse.json(
        { error: 'xpChange must be a positive number' },
        { status: 400 }
      );
    }

    if (xpChange <= 0) {
      return NextResponse.json(
        { error: 'xpChange must be greater than 0' },
        { status: 400 }
      );
    }

    if (!reason || typeof reason !== 'string' || reason.trim() === '') {
      return NextResponse.json(
        { error: 'reason must be a non-empty string' },
        { status: 400 }
      );
    }

    // 2. Extract user ID from Authorization header
    const authHeader = request.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return NextResponse.json(
        { error: 'Missing or invalid authorization header' },
        { status: 401 }
      );
    }

    const token = authHeader.slice(7); // Remove 'Bearer ' prefix

    // 3. Verify the token and get user
    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser(token);

    if (userError || !user) {
      return NextResponse.json(
        { error: 'Invalid or expired token' },
        { status: 401 }
      );
    }

    const userId = user.id;

    // 4. Call the award_xp function using service role
    const { error: xpError } = await supabase.rpc('award_xp', {
      p_user_id: userId,
      p_xp_change: xpChange,
      p_reason: reason.trim(),
    });

    if (xpError) {
      console.error('XP award error:', xpError);
      return NextResponse.json(
        { error: 'Failed to award XP', details: xpError.message },
        { status: 500 }
      );
    }

    // 5. Log the successful XP award
    console.log(`[XP_AWARD] User: ${userId}, XP: +${xpChange}, Reason: ${reason}`);

    return NextResponse.json(
      {
        success: true,
        message: `Successfully awarded ${xpChange} XP`,
        userId,
        xpChange,
        reason,
      },
      { status: 200 }
    );
  } catch (error: unknown) {
    console.error('XP award endpoint error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json(
      { error: 'Internal server error', details: errorMessage },
      { status: 500 }
    );
  }
}
