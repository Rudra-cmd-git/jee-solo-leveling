import { describe, expect, it } from 'vitest';
import {
  MAX_TASK_XP,
  RANK_THRESHOLDS,
  formatNumber,
  getRank,
  getRankProgress,
} from './utils';

describe('getRank', () => {
  it('starts every new player at E', () => {
    expect(getRank(0)).toBe('E');
    expect(getRank(RANK_THRESHOLDS.D - 1)).toBe('E');
  });

  it('promotes exactly at each threshold', () => {
    expect(getRank(RANK_THRESHOLDS.D)).toBe('D');
    expect(getRank(RANK_THRESHOLDS.C)).toBe('C');
    expect(getRank(RANK_THRESHOLDS.B)).toBe('B');
    expect(getRank(RANK_THRESHOLDS.A)).toBe('A');
    expect(getRank(RANK_THRESHOLDS.S)).toBe('S');
  });

  it('caps at S for very large XP', () => {
    expect(getRank(1_000_000)).toBe('S');
  });
});

describe('getRankProgress', () => {
  it('reports 0% at the start of a rank', () => {
    const progress = getRankProgress(0);
    expect(progress.currentRank).toBe('E');
    expect(progress.nextRank).toBe('D');
    expect(progress.progress).toBe(0);
    expect(progress.xpToNextRank).toBe(RANK_THRESHOLDS.D);
  });

  it('reports halfway progress inside a rank', () => {
    const halfway = (RANK_THRESHOLDS.D + RANK_THRESHOLDS.C) / 2;
    const progress = getRankProgress(halfway);
    expect(progress.currentRank).toBe('D');
    expect(progress.nextRank).toBe('C');
    expect(progress.progress).toBeCloseTo(50);
  });

  it('treats S as the final rank', () => {
    const progress = getRankProgress(RANK_THRESHOLDS.S + 5000);
    expect(progress.currentRank).toBe('S');
    expect(progress.nextRank).toBeNull();
    expect(progress.progress).toBe(100);
    expect(progress.xpToNextRank).toBe(0);
  });
});

describe('formatNumber', () => {
  it('adds thousands separators', () => {
    expect(formatNumber(999)).toBe('999');
    expect(formatNumber(1000)).toBe('1,000');
    expect(formatNumber(1234567)).toBe('1,234,567');
  });
});

describe('MAX_TASK_XP', () => {
  it('matches the database cap in migration 002', () => {
    expect(MAX_TASK_XP).toBe(500);
  });
});
