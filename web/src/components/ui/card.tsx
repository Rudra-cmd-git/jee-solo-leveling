'use client';

import * as React from 'react';
import { clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function card(
  className: string,
  { ...props }: React.HTMLAttributes<HTMLDivElement>
) {
  return (
    <div
      className={twMerge('rounded-xl border bg-card text-card-foreground shadow-sm system', clsx(props.className))}
      {...props}
    />
  );
}

card.displayName = 'card';
export default card;
