import type { NextConfig } from 'next';

const config: NextConfig = {
  // The core package ships raw TypeScript so the same source runs in Node,
  // the Next server and a Cloudflare Worker without a build step.
  transpilePackages: ['@widgeto/core'],
};

export default config;
