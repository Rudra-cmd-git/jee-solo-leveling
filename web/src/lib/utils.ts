import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export const RANKS = ['E', 'D', 'C', 'B', 'A', 'S'] as const;
export type Rank = typeof RANKS[number];

export const RANK_THRESHOLDS: Record<Rank, number> = {
  E: 0,
  D: 1000,
  C: 2500,
  B: 5000,
  A: 10000,
  S: 25000,
};

export function getRank(xp: number): Rank {
  for (let i = RANKS.length - 1; i >= 0; i--) {
    const rank = RANKS[i];
    if (xp >= RANK_THRESHOLDS[rank]) {
      return rank as Rank;
    }
  }
  return 'E'; // fallback
}

export function getRankProgress(xp: number) {
  const currentRank = getRank(xp);
  const currentIndex = RANKS.indexOf(currentRank);

  // If already at max rank
  if (currentIndex === RANKS.length - 1) {
    return {
      currentRank,
      nextRank: null,
      progress: 100,
      xpToNextRank: 0,
      xpInCurrentRank: xp - RANK_THRESHOLDS[currentRank],
    };
  }

  const nextRank = RANKS[currentIndex + 1] as Rank;
  const currentRankXp = RANK_THRESHOLDS[currentRank];
  const nextRankXp = RANK_THRESHOLDS[nextRank];

  const xpInCurrentRank = xp - currentRankXp;
  const xpToNextRank = nextRankXp - xp;
  const totalXpForRank = nextRankXp - currentRankXp;
  const progress = (xpInCurrentRank / totalXpForRank) * 100;

  return {
    currentRank,
    nextRank,
    progress: Math.min(100, Math.max(0, progress)),
    xpToNextRank: Math.max(0, xpToNextRank),
    xpInCurrentRank,
  };
}

export function formatNumber(num: number): string {
  return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

export function formatDate(dateString: string): string {
  return new Date(dateString).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}