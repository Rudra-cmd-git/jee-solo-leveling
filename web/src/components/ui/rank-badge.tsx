'use client';

import * as React from 'react';
import { cn } from '@/lib/utils';
import type { Rank } from '@/lib/utils';

interface RankBadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  rank: Rank;
  size?: 'sm' | 'md' | 'lg';
  /** Render as "S RANK" instead of just "S". */
  withLabel?: boolean;
}

const SIZE_CLASS = {
  sm: 'text-xs',
  md: 'text-sm',
  lg: 'text-lg px-3 py-1',
} as const;

export function RankBadge({
  rank,
  className,
  size = 'md',
  withLabel = false,
  ...props
}: RankBadgeProps) {
  return (
    <span
      className={cn('rank-badge', `rank-badge-${rank}`, SIZE_CLASS[size], className)}
      {...props}
    >
      {rank}
      {withLabel && <span className="opacity-80">RANK</span>}
    </span>
  );
}

export default RankBadge;
