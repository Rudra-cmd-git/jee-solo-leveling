/**
 * API Route: /api/tasks
 * POST: Create a new task
 * GET: List authenticated user's tasks
 */

import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import { getAuthenticatedUser } from '@/lib/api-auth';
import {
  validateTitle,
  validateSubject,
  validateXpValue,
  ValidationError,
} from '@/lib/task-validation';

/**
 * Create a Supabase client using service role key
 */
function getSupabaseClient() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseServiceRoleKey) {
    throw new Error(
      'Missing Supabase environment variables: NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY'
    );
  }

  return createClient(supabaseUrl, supabaseServiceRoleKey);
}

/**
 * POST /api/tasks
 * Create a new task for the authenticated user
 */
export async function POST(request: NextRequest) {
  try {
    // 1. Authenticate user
    const user = await getAuthenticatedUser(request);

    // 2. Parse request body
    const body = await request.json();
    const { title, subject, xpValue } = body;

    // 3. Validate inputs
    const validatedTitle = validateTitle(title);
    const validatedSubject = validateSubject(subject);
    const validatedXpValue = validateXpValue(xpValue);

    // 4. Create Supabase client
    const supabase = getSupabaseClient();

    // 5. Insert task into database
    // Note: user_id, status, timestamps are server-controlled
    const { data, error } = await supabase
      .from('tasks')
      .insert({
        user_id: user.id,
        title: validatedTitle,
        subject: validatedSubject,
        xp_value: validatedXpValue,
        status: 'pending',
      })
      .select()
      .single();

    if (error) {
      console.error('Database error creating task:', error);
      return NextResponse.json(
        { error: 'Failed to create task', details: error.message },
        { status: 500 }
      );
    }

    // 6. Return created task
    return NextResponse.json(
      {
        success: true,
        task: data,
      },
      { status: 201 }
    );
  } catch (err: unknown) {
    // Handle validation errors
    if (err instanceof ValidationError) {
      return NextResponse.json(
        { error: err.message },
        { status: 400 }
      );
    }

    // Handle authentication errors
    if (err instanceof Error) {
      if (err.message.includes('Authorization') || err.message.includes('token')) {
        return NextResponse.json(
          { error: err.message },
          { status: 401 }
        );
      }

      console.error('Task creation error:', err);
      return NextResponse.json(
        { error: 'Internal server error', details: err.message },
        { status: 500 }
      );
    }

    console.error('Unexpected error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

/**
 * GET /api/tasks
 * List all tasks for the authenticated user
 * Optional query parameters:
 *   - status: 'pending' | 'approved' | 'rejected' (filter by status)
 *   - sortBy: 'created' | 'updated' (sort order, default: 'created')
 */
export async function GET(request: NextRequest) {
  try {
    // 1. Authenticate user
    const user = await getAuthenticatedUser(request);

    // 2. Parse query parameters
    const { searchParams } = new URL(request.url);
    const statusFilter = searchParams.get('status');
    const sortBy = searchParams.get('sortBy') || 'created';

    // 3. Validate query parameters
    const validStatuses = ['pending', 'approved', 'rejected'];
    if (statusFilter && !validStatuses.includes(statusFilter)) {
      return NextResponse.json(
        { error: 'Invalid status filter' },
        { status: 400 }
      );
    }

    const validSortOptions = ['created', 'updated'];
    if (!validSortOptions.includes(sortBy)) {
      return NextResponse.json(
        { error: 'Invalid sortBy option' },
        { status: 400 }
      );
    }

    // 4. Create Supabase client
    const supabase = getSupabaseClient();

    // 5. Build query
    let query = supabase
      .from('tasks')
      .select('*')
      .eq('user_id', user.id);

    // Apply status filter if provided
    if (statusFilter) {
      query = query.eq('status', statusFilter);
    }

    // Apply sorting
    const orderColumn = sortBy === 'created' ? 'created_at' : 'updated_at';
    query = query.order(orderColumn, { ascending: false });

    // 6. Execute query
    const { data, error } = await query;

    if (error) {
      console.error('Database error listing tasks:', error);
      return NextResponse.json(
        { error: 'Failed to list tasks', details: error.message },
        { status: 500 }
      );
    }

    // 7. Return tasks
    return NextResponse.json(
      {
        success: true,
        tasks: data || [],
      },
      { status: 200 }
    );
  } catch (err: unknown) {
    // Handle authentication errors
    if (err instanceof Error) {
      if (err.message.includes('Authorization') || err.message.includes('token')) {
        return NextResponse.json(
          { error: err.message },
          { status: 401 }
        );
      }

      console.error('Task listing error:', err);
      return NextResponse.json(
        { error: 'Internal server error', details: err.message },
        { status: 500 }
      );
    }

    console.error('Unexpected error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
