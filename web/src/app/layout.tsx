import type { Metadata } from 'next';
import './globals.css';
import '@fontsource-variable/inter';
import '@fontsource-variable/orbitron';
import { AuthProvider } from '@/lib/auth-context';
import { ToastProvider } from '@/components/ui/toast';
import * as React from 'react';

export const metadata: Metadata = {
  title: 'JEE Solo Leveling — Gamified JEE Study Tracker',
  description:
    'Turn JEE prep into quests. Create study tasks, submit proof, earn XP, rank up from E to S, and climb the leaderboard.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body className="font-inter antialiased">
        <AuthProvider>
          <ToastProvider>{children}</ToastProvider>
        </AuthProvider>
      </body>
    </html>
  );
}
