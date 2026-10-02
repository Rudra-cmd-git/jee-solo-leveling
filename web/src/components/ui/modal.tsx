import * as React from 'react';

import { cn } from '@/lib/utils';

export const ModalPortal = ({ children }: { children: React.ReactNode }) => {
  // Simplified modal without portal dependency for now
  return (
    <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
      <div className="relative w-full max-w-md max-h-[90vh] overflow-y-auto">
        <div className="bg-white rounded-lg p-6 shadow-lg">
          {children}
        </div>
      </div>
    </div>
  );
};

export const ModalOverlay = ({ className, onClick, children }: {
  className?: string;
  onClick: () => void;
  children?: React.ReactNode;
}) => (
  <button
    className={cn(
      'fixed inset-0 z-50 bg-black/50 backdrop-blur-sm',
      className,
    )}
    aria-label="Close"
    onClick={onClick}
  >
    {children}
  </button>
);

export const ModalContent = ({ className, children }: {
  className?: string;
  children: React.ReactNode;
}) => (
  <div
    className={cn(
      'relative bg-white rounded-lg shadow-md w-full max-w-lg p-6',
      className,
    )}
  >
    <div className="space-y-6">{children}</div>
  </div>
);

export const ModalHeader = ({ className, children }: {
  className?: string;
  children: React.ReactNode;
}) => (
  <div
    className={cn('flex flex-col space-y-2 text-center sm:text-left', className)}
  >
    {children}
  </div>
);

export const ModalTitle = ({ className, children }: {
  className?: string;
  children: React.ReactNode;
}) => (
  <h2
    className={cn(
      'text-xl font-semibold leading-none tracking-tight',
      className,
    )}
  >
    {children}
  </h2>
);

export const ModalDescription = ({ className, children }: {
  className?: string;
  children: React.ReactNode;
}) => (
  <p
    className={cn('text-muted-foreground', className)}
  >
    {children}
  </p>
);

export const ModalFooter = ({ className, children }: {
  className?: string;
  children: React.ReactNode;
}) => (
  <div
    className={cn('flex flex-col-reverse sm:flex-row sm:space-x-2 sm:justify-end', className)}
  >
    {children}
  </div>
);