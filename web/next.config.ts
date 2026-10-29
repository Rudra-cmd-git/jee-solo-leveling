import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Allow the dev server to serve client JS/HMR to proxied preview hosts
  // (Arena/e2b preview). Without this, pages render their server HTML but
  // return 403 for /_next chunks, so the app never hydrates.
  allowedDevOrigins: ['*.e2b.app', 'localhost', '127.0.0.1'],
  turbopack: {
    root: process.cwd(),
  },
};

export default nextConfig;
