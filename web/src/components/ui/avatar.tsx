'use client';

import * as React from 'react';
import Image from 'next/image';
import { clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function avatar(
  className: string,
  {
    src,
    alt,
    size = 40,
    className: customClassName,
    ...props
  }: Omit<React.ImgHTMLAttributes<HTMLImageElement>, 'src' | 'width' | 'height'> & {
    src?: string;
    size?: number;
    alt?: string;
  }
) {
  return (
    <Image
      src={src ?? `/avatars/${Math.floor(Math.random() * 10)}.png`}
      alt={alt ?? 'User avatar'}
      width={size}
      height={size}
      className={twMerge('rounded-full object-cover border border-border/50 system', clsx(customClassName))}
      {...props}
    />
  );
}

avatar.displayName = 'avatar';
export default avatar;
