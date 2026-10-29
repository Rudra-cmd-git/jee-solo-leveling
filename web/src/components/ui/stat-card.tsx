'use client';

import * as React from 'react';
import { cn } from '@/lib/utils';

interface StatCardProps {
  title: string;
  value: string | number;
  sublabel?: string;
  icon?: React.ReactNode;
  className?: string;
}

export function StatCard({
  title,
  value,
  sublabel,
  icon,
  className,
}: StatCardProps) {
  return (
    <div className={cn('stat-card', className)}>
      {icon && (
        <div className="mb-2 flex justify-center text-primary">{icon}</div>
      )}
      <div className="stat-label">{title}</div>
      <div className="stat-value">{value}</div>
      {sublabel && (
        <div className="text-sm text-muted-foreground mt-1">{sublabel}</div>
      )}
    </div>
  );
}

export default StatCard;
