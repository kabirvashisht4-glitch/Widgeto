import type { MetadataRoute } from 'next';
import { siteUrl } from './lib/site';

/**
 * Crawlers are welcome on the pages, not on the endpoints.
 *
 * Every `/u/…` URL is generated from handles, so the space is unbounded — a
 * crawler that wandered into it would spend our rate limit and four upstreams'
 * goodwill enumerating strangers' profiles. The API is disallowed for the same
 * reason: it is for programs that were pointed at it deliberately.
 */
export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: '*',
      allow: '/',
      disallow: ['/api/', '/u/'],
    },
    sitemap: `${siteUrl}/sitemap.xml`,
  };
}
