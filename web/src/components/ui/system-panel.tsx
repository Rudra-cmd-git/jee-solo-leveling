'use client';

import * as React from 'react';
import { cn } from '@/lib/utils';

interface SystemPanelProps extends React.HTMLAttributes<HTMLDivElement> {
  title?: string;
  /** Optional element rendered on the right of the panel header. */
  action?: React.ReactNode;
}

export function SystemPanel({
  className,
  title,
  action,
  children,
  ...props
}: SystemPanelProps) {
  return (
    <section className={cn('glass-panel p-6', className)} {...props}>
      {(title || action) && (
        <div className="mb-4 flex items-center justify-between gap-3">
          {title && (
            <h2 className="font-orbitron text-base font-semibold text-primary tracking-widest">
              [{title.toUpperCase()}]
            </h2>
          )}
          {action}
        </div>
      )}
      {children}
    </section>
  );
}

export default SystemPanel;
