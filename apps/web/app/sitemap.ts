import type { MetadataRoute } from 'next';
import { siteUrl } from './lib/site';

/**
 * Only the pages that exist independently of anyone's handles.
 *
 * Profiles are deliberately absent: every `/u/…` URL is generated from whatever
 * someone typed, so there is no finite set to list, and advertising strangers'
 * profiles to search engines is not something this project should do on their
 * behalf.
 */
export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date();

  return [
    { url: siteUrl, lastModified: now, changeFrequency: 'weekly', priority: 1 },
    { url: `${siteUrl}/compare`, lastModified: now, changeFrequency: 'monthly', priority: 0.8 },
    { url: `${siteUrl}/app`, lastModified: now, changeFrequency: 'monthly', priority: 0.8 },
  ];
}
