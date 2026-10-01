import { signOut } from '@/lib/auth';
import { redirect } from 'next/navigation';

export async function POST() {
  await signOut();
  return redirect('/sign-in');
}