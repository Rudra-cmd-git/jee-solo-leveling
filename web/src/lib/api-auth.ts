/**
 * API authentication utilities
 * Used by backend API routes to verify and extract authenticated user identity
 */

import { NextRequest } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import type { User } from '@supabase/supabase-js';

/**
 * Create a Supabase client using service role key
 * This allows the backend to perform privileged operations
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
 * Extract and verify Bearer token from Authorization header
 * Returns the authenticated user if token is valid
 * Throws error if token is missing, invalid, or expired
 */
export async function getAuthenticatedUser(request: NextRequest): Promise<User> {
  // Extract Authorization header
  const authHeader = request.headers.get('authorization');

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new Error('Missing or invalid Authorization header');
  }

  // Extract token (remove 'Bearer ' prefix)
  const token = authHeader.slice(7);

  // Create Supabase client
  const supabase = getSupabaseClient();

  // Verify token and extract user
  const { data: { user }, error } = await supabase.auth.getUser(token);

  if (error || !user) {
    throw new Error('Invalid or expired authentication token');
  }

  return user;
}
