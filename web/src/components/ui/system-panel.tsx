'use client';

import * as React from 'react';

interface SystemPanelProps extends React.HTMLAttributes<HTMLDivElement> {
  className?: string;
  title?: string;
}

export function SystemPanel({
  className = '',
  title,
  children,
  ...props
}: SystemPanelProps) {
  return (
    <div
      className={
        'glass-panel rounded-xl border border-primary/20 p-6' +
        (className ? ` ${className}` : '')
      }
      {...props}
    >
      {title && (
        <div className="mb-4">
          <h3 className="text-orbitron text-lg font-semibold text-primary mb-2">
            [{title.toUpperCase()}]
          </h3>
        </div>
      )}
      {children}
    </div>
  );
}

SystemPanel.displayName = 'SystemPanel';
export default SystemPanel;