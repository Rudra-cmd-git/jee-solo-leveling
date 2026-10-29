'use client';

import * as React from 'react';
import { CheckCircle2, X, XCircle, AlertTriangle, Info } from 'lucide-react';
import { cn } from '@/lib/utils';

type ToastVariant = 'default' | 'success' | 'error' | 'warning';

interface ToastItem {
  id: number;
  title: string;
  description?: string;
  variant: ToastVariant;
}

interface ToastContextValue {
  toast: (input: Omit<ToastItem, 'id' | 'variant'> & { variant?: ToastVariant }) => void;
}

const ToastContext = React.createContext<ToastContextValue | undefined>(
  undefined,
);

export function useToast() {
  const context = React.useContext(ToastContext);
  if (!context) {
    throw new Error('useToast must be used within a ToastProvider');
  }
  return context;
}

const VARIANT_STYLES: Record<ToastVariant, { border: string; Icon: typeof Info }> = {
  default: { border: 'border-primary/30', Icon: Info },
  success: { border: 'border-green-500/50', Icon: CheckCircle2 },
  error: { border: 'border-red-500/50', Icon: XCircle },
  warning: { border: 'border-yellow-500/50', Icon: AlertTriangle },
};

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = React.useState<ToastItem[]>([]);
  const nextId = React.useRef(1);

  const dismiss = React.useCallback((id: number) => {
    setToasts((current) => current.filter((item) => item.id !== id));
  }, []);

  const toast = React.useCallback<ToastContextValue['toast']>(
    (input) => {
      const id = nextId.current++;
      setToasts((current) => [
        ...current.slice(-3),
        { id, variant: 'default', ...input },
      ]);
      window.setTimeout(() => dismiss(id), 5000);
    },
    [dismiss],
  );

  return (
    <ToastContext.Provider value={{ toast }}>
      {children}
      <div
        aria-live="polite"
        className="fixed bottom-4 right-4 z-[60] flex w-[min(92vw,360px)] flex-col gap-2"
      >
        {toasts.map((item) => {
          const { border, Icon } = VARIANT_STYLES[item.variant];
          return (
            <div
              key={item.id}
              role="status"
              className={cn(
                'glass-panel flex items-start gap-3 p-4 animate-slideUp',
                border,
              )}
            >
              <Icon className="h-5 w-5 shrink-0 text-primary" aria-hidden />
              <div className="min-w-0 flex-1">
                <p className="font-orbitron text-sm font-semibold text-foreground">
                  [{item.variant.toUpperCase()}] {item.title}
                </p>
                {item.description && (
                  <p className="mt-1 text-sm text-muted-foreground break-words">
                    {item.description}
                  </p>
                )}
              </div>
              <button
                type="button"
                onClick={() => dismiss(item.id)}
                aria-label="Dismiss notification"
                className="rounded p-0.5 text-muted-foreground hover:text-foreground"
              >
                <X className="h-4 w-4" aria-hidden />
              </button>
            </div>
          );
        })}
      </div>
    </ToastContext.Provider>
  );
}
