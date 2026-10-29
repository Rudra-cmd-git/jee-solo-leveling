'use client';

import * as React from 'react';
import { cn } from '@/lib/utils';

export interface AvatarProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Optional image URL. When absent, initials from `name` are shown. */
  src?: string | null;
  name?: string | null;
  size?: number;
}

/**
 * Player avatar. Falls back to deterministic initials — no random images,
 * no requests to files that do not exist.
 */
function Avatar({ src, name, size = 40, className, ...props }: AvatarProps) {
  const initials = (name ?? 'P')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part.charAt(0).toUpperCase())
    .join('');

  if (src) {
    return (
      // User-provided URLs come from arbitrary hosts, so next/image's
      // remote allowlist does not apply here; a plain img is intentional.
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={src}
        alt={name ? `${name} avatar` : 'User avatar'}
        width={size}
        height={size}
        style={{ width: size, height: size }}
        className={cn(
          'rounded-full object-cover border border-primary/30 shrink-0',
          className,
        )}
      />
    );
  }

  return (
    <span
      role="img"
      aria-label={name ? `${name} avatar` : 'User avatar'}
      style={{ width: size, height: size, fontSize: Math.round(size * 0.38) }}
      className={cn(
        'inline-flex items-center justify-center rounded-full shrink-0',
        'bg-primary/15 border border-primary/30 text-primary font-orbitron font-bold',
        className,
      )}
      {...props}
    >
      {initials || 'P'}
    </span>
  );
}

export { Avatar };
export default Avatar;
