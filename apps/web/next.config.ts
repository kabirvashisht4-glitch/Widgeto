import type { NextConfig } from 'next';

const config: NextConfig = {
  // The core package ships raw TypeScript so the same source runs in Node,
  // the Next server and a Cloudflare Worker without a build step.
  transpilePackages: ['@widgeto/core'],

  async rewrites() {
    return [
      // The Flutter app is built into public/app as a static PWA. Next serves
      // files from public/ but does not resolve a directory to its index, so
      // /app would 404 even though /app/index.html exists.
      { source: '/app', destination: '/app/index.html' },
      { source: '/app/', destination: '/app/index.html' },
    ];
  },

  async headers() {
    return [
      {
        // The service worker must be revalidated every load, or a stale one
        // pins users to an old build forever.
        source: '/app/flutter_service_worker.js',
        headers: [{ key: 'Cache-Control', value: 'no-cache, no-store, must-revalidate' }],
      },
      {
        source: '/app/index.html',
        headers: [{ key: 'Cache-Control', value: 'no-cache' }],
      },
      {
        // Everything else the app ships is content-hashed by the Flutter build.
        source: '/app/:path((?!index\\.html|flutter_service_worker\\.js).*)',
        headers: [{ key: 'Cache-Control', value: 'public, max-age=604800' }],
      },
    ];
  },
};

export default config;
