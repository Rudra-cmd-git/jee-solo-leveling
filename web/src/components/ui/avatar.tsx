'use client';

import * as React from 'react';
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function avatar(
  className: string,
  {
    src,
    alt,
    size = 40,
    ...props
  }: React.ImgHTMLAttributes<HTMLImageElement> & {
    size?: number;
    alt?: string;
  }
) {
  return (
    <img
      src={src ?? `/avatars/${Math.floor(Math.random() * 10)}.png`}
      alt={alt ?? 'User avatar'}
      width={size}
      height={size}
      className={twMerge('h-{size} w-{size} rounded-full object-cover border border-border/50', clsx(props.className))}
      {...props}
    />
  );
}

avatar.displayName = 'avatar';
export default avatar;
