/**
 * API Route: /api/tasks/[id]
 * PUT: Update a task (title/subject only)
 * DELETE: Delete a task
 */

import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import { getAuthenticatedUser } from '@/lib/api-auth';
import {
  validateTitle,
  validateSubject,
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
 * PUT /api/tasks/[id]
 * Update a task (only title and subject allowed)
 */
export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    // 1. Authenticate user
    const user = await getAuthenticatedUser(request);

    // 2. Extract task ID from path (params is a Promise in Next.js 16)
    const { id: taskId } = await params;

    if (!taskId || typeof taskId !== 'string') {
      return NextResponse.json(
        { error: 'Invalid task ID' },
        { status: 400 }
      );
    }

    // 3. Parse request body
    const body = await request.json();
    const { title, subject } = body;

    // 4. Check for forbidden fields
    const forbiddenFields = [
      'id',
      'user_id',
      'xp_value',
      'status',
      'created_at',
      'updated_at',
    ];
    const bodyKeys = Object.keys(body);
    const presentForbiddenFields = bodyKeys.filter((key) =>
      forbiddenFields.includes(key)
    );

    if (presentForbiddenFields.length > 0) {
      return NextResponse.json(
        {
          error: 'Cannot update server-controlled fields',
          forbiddenFields: presentForbiddenFields,
        },
        { status: 400 }
      );
    }

    // 5. Build update object with only allowed fields
    const updateData: Record<string, unknown> = {};

    if (title !== undefined) {
      updateData.title = validateTitle(title);
    }

    if (subject !== undefined) {
      updateData.subject = validateSubject(subject);
    }

    // If no fields to update, return error
    if (Object.keys(updateData).length === 0) {
      return NextResponse.json(
        { error: 'No valid fields to update' },
        { status: 400 }
      );
    }

    // 6. Update updated_at timestamp
    updateData.updated_at = new Date().toISOString();

    // 7. Create Supabase client
    const supabase = getSupabaseClient();

    // 8. Verify ownership before updating (IDOR prevention)
    const { data: existingTask, error: selectError } = await supabase
      .from('tasks')
      .select('id, user_id')
      .eq('id', taskId)
      .eq('user_id', user.id)
      .single();

    if (selectError || !existingTask) {
      return NextResponse.json(
        { error: 'Task not found or not owned by user' },
        { status: 404 }
      );
    }

    // 9. Update task (also constrained to user_id to defend in depth)
    const { data, error } = await supabase
      .from('tasks')
      .update(updateData)
      .eq('id', taskId)
      .eq('user_id', user.id)
      .select()
      .single();

    if (error) {
      console.error('Database error updating task:', error);
      return NextResponse.json(
        { error: 'Failed to update task', details: error.message },
        { status: 500 }
      );
    }

    // 10. Return updated task
    return NextResponse.json(
      {
        success: true,
        task: data,
      },
      { status: 200 }
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

      console.error('Task update error:', err);
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
 * DELETE /api/tasks/[id]
 * Delete a task (only if owned by authenticated user)
 */
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    // 1. Authenticate user
    const user = await getAuthenticatedUser(request);

    // 2. Extract task ID from path (params is a Promise in Next.js 16)
    const { id: taskId } = await params;

    if (!taskId || typeof taskId !== 'string') {
      return NextResponse.json(
        { error: 'Invalid task ID' },
        { status: 400 }
      );
    }

    // 3. Create Supabase client
    const supabase = getSupabaseClient();

    // 4. Verify ownership before deleting (IDOR prevention)
    const { data: existingTask, error: selectError } = await supabase
      .from('tasks')
      .select('id, user_id')
      .eq('id', taskId)
      .eq('user_id', user.id)
      .single();

    if (selectError || !existingTask) {
      return NextResponse.json(
        { error: 'Task not found or not owned by user' },
        { status: 404 }
      );
    }

    // 5. Delete task (ownership enforced via WHERE clause)
    const { error } = await supabase
      .from('tasks')
      .delete()
      .eq('id', taskId)
      .eq('user_id', user.id);

    if (error) {
      console.error('Database error deleting task:', error);
      return NextResponse.json(
        { error: 'Failed to delete task', details: error.message },
        { status: 500 }
      );
    }

    // 6. Return success
    return NextResponse.json(
      {
        success: true,
        message: 'Task deleted successfully',
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

      console.error('Task deletion error:', err);
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

