'use client';

import * as React from 'react';

interface ToastProps {
  title: string;
  description?: string;
  variant?: 'default' | 'success' | 'error' | 'warning';
  className?: string;
  onClose?: () => void;
}

export function Toast({
  title,
  description,
  variant = 'default',
  className = '',
  onClose,
}: ToastProps) {
  const variantClass = {
    success: 'border-green-500/40',
    error: 'border-red-500/40',
    warning: 'border-yellow-500/40',
    default: 'border-primary/20',
  }[variant];

  return (
    <div
      className={
        `toast ${variantClass} ${className}`
      }
      role="alert"
    >
      <div className="toast-header">
        <h3 className="toast-title">
          [{variant.toUpperCase()}] {title}
        </h3>
        {onClose && (
          <button
            onClick={onClose}
            className="toast-close"
            aria-label="Close"
          >
            ×
          </button>
        )}
      </div>
      {description && (
        <p className="toast-content mt-2">{description}</p>
      )}
    </div>
  );
}

Toast.displayName = 'Toast';
export default Toast;