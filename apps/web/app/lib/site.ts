/**
 * Where this deployment lives.
 *
 * Shared by the layout's metadata, robots and the sitemap so they cannot
 * disagree. It follows the deployment rather than being hard-coded, which is
 * what keeps a preview deploy from advertising production's URL as canonical.
 */
export const siteUrl =
  process.env.NEXT_PUBLIC_SITE_URL ??
  (process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : 'http://localhost:3210');
