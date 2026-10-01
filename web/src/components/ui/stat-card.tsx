'use client';

import * as React from 'react';

interface StatCardProps {
  title: string;
  value: string | number;
  icon?: React.ReactNode;
  className?: string;
}

export function StatCard({
  title,
  value,
  icon,
  className = '',
}: StatCardProps) {
  return (
    <div className={`stat-card ${className}`}>
      {icon && <div className="mb-3">{icon}</div>}
      <div className="stat-value">{value}</div>
      <div className="stat-label">{title}</div>
    </div>
  );
}

StatCard.displayName = 'StatCard';
export default StatCard;