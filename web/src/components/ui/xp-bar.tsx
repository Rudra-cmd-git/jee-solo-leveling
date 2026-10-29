'use client';

import * as React from 'react';
import { getRankProgress, formatNumber, cn } from '@/lib/utils';

interface XPBarProps {
  xp: number;
  className?: string;
  showText?: boolean;
}

export function XPBar({ xp, className, showText = true }: XPBarProps) {
  const { progress, currentRank, nextRank, xpToNextRank } =
    getRankProgress(xp);

  return (
    <div className={cn('w-full', className)}>
      <div className="flex items-center justify-between mb-2">
        <span className="text-sm font-orbitron text-primary">
          Rank {currentRank}
          {nextRank ? ` → ${nextRank}` : ' (MAX)'}
        </span>
        {showText && (
          <span className="text-sm font-orbitron text-primary">
            {progress.toFixed(0)}%
            {xpToNextRank > 0
              ? ` (${formatNumber(xpToNextRank)} XP to go)`
              : ''}
          </span>
        )}
      </div>
      <div
        className="xp-bar mt-0"
        role="progressbar"
        aria-valuenow={Math.round(progress)}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={`Progress to next rank: ${progress.toFixed(0)} percent`}
      >
        <div className="xp-bar-fill" style={{ width: `${progress}%` }} />
      </div>
    </div>
  );
}

export default XPBar;
