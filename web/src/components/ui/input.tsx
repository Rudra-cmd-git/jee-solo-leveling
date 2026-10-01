'use client';

import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

const inputVariants = cva(
  'flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50',
  {
    variants: {},
    defaultVariants: {},
  }
);

export function input(
  className: string,
  { ...props }: VariantProps<typeof inputVariants> & React.InputHTMLAttributes<HTMLInputElement>
) {
  return (
    <input
      className={twMerge(inputVariants(), clsx(props.className))}
      {...props}
    />
  );
}

input.displayName = 'input';
export default input;
