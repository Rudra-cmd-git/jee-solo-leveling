'use client';

import * as React from 'react';

interface RankBadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  rank: 'E' | 'D' | 'C' | 'B' | 'A' | 'S';
  className?: string;
  size?: 'sm' | 'md' | 'lg';
}

export function RankBadge({
  rank,
  className = '',
  size = 'md',
  ...props
}: RankBadgeProps) {
  const sizeClass = size === 'sm' ? 'text-xs' : size === 'lg' ? 'text-lg' : 'text-sm';

  return (
    <span
      className={
        `rank-badge rank-badge.${rank} ${sizeClass} ${className}`
      }
      {...props}
    >
      {rank}
    </span>
  );
}

RankBadge.displayName = 'RankBadge';
export default RankBadge;