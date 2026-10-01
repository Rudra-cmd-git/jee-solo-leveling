'use client';

import * as React from 'react';
import { getRankProgress } from '@/lib/utils';

interface XPBarProps {
  xp: number;
  className?: string;
  showText?: boolean;
}

export function XPBar({
  xp,
  className = '',
  showText = true,
}: XPBarProps) {
  const { progress, currentRank, nextRank, xpToNextRank } = getRankProgress(xp);

  return (
    <div className={`${className} w-full`}>
      <div className="flex items-center justify-between mb-2">
        <div className="text-sm font-orbitron text-primary">
          Rank: {currentRank}{nextRank ? ` → ${nextRank}` : ' (MAX)'}
        </div>
        {showText && (
          <div className="text-sm font-orbitron text-primary">
            {progress.toFixed(0)}%{xpToNextRank > 0 ? ` (${xpToNextRank} XP to go)` : ''}
          </div>
        )}
      </div>
      <div className="w-full h-2 bg-white/10 rounded overflow-hidden">
        <div
          className="h-full bg-gradient-to-r from-primary via-secondary rounded transition-all duration-1000 ease-out shadow-glow"
          style={{ width: `${progress}%` }}
        ></div>
      </div>
    </div>
  );
}

XPBar.displayName = 'XPBar';
export default XPBar;