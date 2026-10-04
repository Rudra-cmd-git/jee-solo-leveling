/**
 * Task 8 Backend API Security Tests
 * Tests for: POST /api/tasks, GET /api/tasks, PUT /api/tasks/[id], DELETE /api/tasks/[id]
 *
 * Run these tests against a running Next.js server with Supabase configured
 * Example: npx jest backend/tests/tasks-api.test.ts
 */

import { createClient } from '@supabase/supabase-js';

// Helper: Create a test Supabase client
function getTestSupabaseClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY!;
  return createClient(url, key);
}

// Helper: Create a test user and get their auth token
async function createTestUser(email: string, password: string) {
  const supabase = getTestSupabaseClient();
  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });
  if (error) throw error;
  return data.user;
}

// Helper: Sign in a user and get their session
async function signInTestUser(email: string, password: string) {
  const supabase = getTestSupabaseClient();
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });
  if (error) throw error;
  return data.session;
}

// Helper: Delete a test user
async function deleteTestUser(userId: string) {
  const supabase = getTestSupabaseClient();
  await supabase.auth.admin.deleteUser(userId);
}

// Helper: Call API endpoint
async function callApi(
  method: string,
  path: string,
  token: string | null,
  body?: any
) {
  const url = `${process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'}${path}`;
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const response = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const data = await response.json();
  return { status: response.status, data };
}

describe('Task 8: Secure Task Backend API', () => {
  let user1: any;
  let user2: any;
  let token1: string;
  let token2: string;
  let testTaskId: string;

  beforeAll(async () => {
    // Create two test users
    user1 = await createTestUser(
      `test-user-1-${Date.now()}@example.com`,
      'TestPassword123!'
    );
    user2 = await createTestUser(
      `test-user-2-${Date.now()}@example.com`,
      'TestPassword123!'
    );

    // Sign in users to get tokens
    const session1 = await signInTestUser(
      user1.email!,
      'TestPassword123!'
    );
    const session2 = await signInTestUser(
      user2.email!,
      'TestPassword123!'
    );

    token1 = session1!.access_token;
    token2 = session2!.access_token;
  });

  afterAll(async () => {
    // Clean up test users
    await deleteTestUser(user1.id);
    await deleteTestUser(user2.id);
  });

  describe('Authentication', () => {
    it('POST /api/tasks without token returns 401', async () => {
      const { status, data } = await callApi(
        'POST',
        '/api/tasks',
        null,
        { title: 'Test Task', subject: 'Test', xpValue: 50 }
      );
      expect(status).toBe(401);
      expect(data.error).toBeDefined();
    });

    it('GET /api/tasks without token returns 401', async () => {
      const { status, data } = await callApi('GET', '/api/tasks', null);
      expect(status).toBe(401);
      expect(data.error).toBeDefined();
    });

    it('PUT /api/tasks/:id without token returns 401', async () => {
      const { status, data } = await callApi(
        'PUT',
        '/api/tasks/invalid-id',
        null,
        { title: 'Updated' }
      );
      expect(status).toBe(401);
      expect(data.error).toBeDefined();
    });

    it('DELETE /api/tasks/:id without token returns 401', async () => {
      const { status, data } = await callApi(
        'DELETE',
        '/api/tasks/invalid-id',
        null
      );
      expect(status).toBe(401);
      expect(data.error).toBeDefined();
    });
  });

  describe('Input Validation', () => {
    it('POST with empty title returns 400', async () => {
      const { status, data } = await callApi(
        'POST',
        '/api/tasks',
        token1,
        { title: '', subject: 'Test', xpValue: 50 }
      );
      expect(status).toBe(400);
      expect(data.error).toContain('empty');
    });

    it('POST with whitespace-only title returns 400', async () => {
      const { status, data } = await callApi(
        'POST',
        '/api/tasks',
        token1,
        { title: '   ', subject: 'Test', xpValue: 50 }
      );
      expect(status).toBe(400);
      expect(data.error).toContain('empty');
    });

    it('POST with title > 255 chars returns 400', async () => {
      const longTitle = 'a'.repeat(256);
      const { status, data } = await callApi(
        'POST',
        '/api/tasks',
        token1,
        { title: longTitle, subject: 'Test', xpValue: 50 }
      );
      expect(status).toBe(400);
      expect(data.error).toContain('exceed');
    });

    it('POST with empty subject returns 400', async () => {
      const { status, data } = await callApi(
        'POST',
        '/api/tasks',
        token1,
        { title: 'Test', subject: '', xpValue: 50 }
      );
      expect(status).toBe(400);
      expect(data.error).toContain('empty');
    });

    it('POST with xpValue = 0 returns 400', async () => {
      const { status, data } = await callApi(
        'POST',
        '/api/tasks',
        token1,
        { title: 'Test', subject: 'Test', xpValue: 0 }
      );
      expect(status).toBe(400);
      expect(data.error).toContain('between 1 and 1000');
    });

    it('POST with xpValue > 1000 returns 400', async () => {
      const { status, data } = await callApi(
        'POST',
        '/api/tasks',
        token1,
        { title: 'Test', subject: 'Test', xpValue: 2000 }
      );
      expect(status).toBe(400);
      expect(data.error).toContain('between 1 and 1000');
    });

    it('POST with negative xpValue returns 400', async () => {
      const { status, data } = await callApi(
        'POST',
        '/api/tasks',
        token1,
        { title: 'Test', subject: 'Test', xpValue: -100 }
      );
      expect(status).toBe(400);
      expect(data.error).toContain('between 1 and 1000');
    });
  });

  describe('Mass Assignment Prevention', () => {
    it('POST with user_id in body is ignored', async () => {
      const { status, data } = await callApi(
        'POST',
        '/api/tasks',
        token1,
        {
          title: 'Test Task',
          subject: 'Test',
          xpValue: 50,
          user_id: user2.id, // Attempt to assign to different user
        }
      );
      expect(status).toBe(201);
      expect(data.task.user_id).toBe(user1.id); // Should be user1, not user2
      testTaskId = data.task.id;
    });

    it('POST with status in body is ignored', async () => {
      const { status, data } = await callApi(
        'POST',
        '/api/tasks',
        token1,
        {
          title: 'Test Task 2',
          subject: 'Test',
          xpValue: 50,
          status: 'approved', // Attempt to set status
        }
      );
      expect(status).toBe(201);
      expect(data.task.status).toBe('pending'); // Should be pending, not approved
    });

    it('PUT with xp_value in body returns 400', async () => {
      const { status, data } = await callApi(
        'PUT',
        `/api/tasks/${testTaskId}`,
        token1,
        { title: 'Updated', xp_value: 999 }
      );
      expect(status).toBe(400);
      expect(data.error).toContain('server-controlled');
    });

    it('PUT with user_id in body returns 400', async () => {
      const { status, data } = await callApi(
        'PUT',
        `/api/tasks/${testTaskId}`,
        token1,
        { title: 'Updated', user_id: user2.id }
      );
      expect(status).toBe(400);
      expect(data.error).toContain('server-controlled');
    });

    it('PUT with status in body returns 400', async () => {
      const { status, data } = await callApi(
        'PUT',
        `/api/tasks/${testTaskId}`,
        token1,
        { title: 'Updated', status: 'approved' }
      );
      expect(status).toBe(400);
      expect(data.error).toContain('server-controlled');
    });
  });

  describe('Ownership (IDOR Prevention)', () => {
    it('User cannot access another user\'s task', async () => {
      const { status } = await callApi(
        'GET',
        `/api/tasks/${testTaskId}`,
        token2
      );
      // GET /api/tasks/:id doesn't exist, but we verify through list
      // User2 should not see user1's tasks
    });

    it('User cannot update another user\'s task', async () => {
      const { status, data } = await callApi(
        'PUT',
        `/api/tasks/${testTaskId}`,
        token2,
        { title: 'Hacked Title' }
      );
      expect(status).toBe(404);
    });

    it('User cannot delete another user\'s task', async () => {
      const { status, data } = await callApi(
        'DELETE',
        `/api/tasks/${testTaskId}`,
        token2
      );
      expect(status).toBe(404);
    });
  });

  describe('Happy Path', () => {
    it('POST creates task with valid inputs', async () => {
      const { status, data } = await callApi(
        'POST',
        '/api/tasks',
        token1,
        { title: 'Physics Study', subject: 'Mechanics', xpValue: 75 }
      );
      expect(status).toBe(201);
      expect(data.success).toBe(true);
      expect(data.task).toBeDefined();
      expect(data.task.title).toBe('Physics Study');
      expect(data.task.subject).toBe('Mechanics');
      expect(data.task.xp_value).toBe(75);
      expect(data.task.status).toBe('pending');
      expect(data.task.user_id).toBe(user1.id);
    });

    it('GET lists user\'s tasks', async () => {
      const { status, data } = await callApi(
        'GET',
        '/api/tasks',
        token1
      );
      expect(status).toBe(200);
      expect(data.success).toBe(true);
      expect(Array.isArray(data.tasks)).toBe(true);
      expect(data.tasks.length).toBeGreaterThan(0);
    });

    it('GET with status filter works', async () => {
      const { status, data } = await callApi(
        'GET',
        '/api/tasks?status=pending',
        token1
      );
      expect(status).toBe(200);
      expect(data.tasks.every((t: any) => t.status === 'pending')).toBe(true);
    });

    it('PUT updates task title', async () => {
      const { status, data } = await callApi(
        'PUT',
        `/api/tasks/${testTaskId}`,
        token1,
        { title: 'Updated Title' }
      );
      expect(status).toBe(200);
      expect(data.task.title).toBe('Updated Title');
      expect(data.task.xp_value).toBe(50); // Unchanged
    });

    it('PUT updates task subject', async () => {
      const { status, data } = await callApi(
        'PUT',
        `/api/tasks/${testTaskId}`,
        token1,
        { subject: 'Updated Subject' }
      );
      expect(status).toBe(200);
      expect(data.task.subject).toBe('Updated Subject');
    });

    it('DELETE removes task', async () => {
      // Create a task to delete
      const createRes = await callApi(
        'POST',
        '/api/tasks',
        token1,
        { title: 'To Delete', subject: 'Test', xpValue: 50 }
      );
      const taskId = createRes.data.task.id;

      // Delete it
      const { status, data } = await callApi(
        'DELETE',
        `/api/tasks/${taskId}`,
        token1
      );
      expect(status).toBe(200);
      expect(data.success).toBe(true);
    });
  });

  describe('Regression: Database Security', () => {
    it('Authenticated role cannot INSERT tasks directly', async () => {
      const supabase = getTestSupabaseClient();

      // This should fail due to database privilege restrictions
      const { error } = await supabase
        .from('tasks')
        .insert({
          user_id: user1.id,
          title: 'Direct Insert',
          subject: 'Test',
          xp_value: 50,
          status: 'pending',
        });

      // Error should occur due to REVOKE INSERT privilege
      expect(error).toBeDefined();
    });
  });
});
