import type { Metadata } from 'next';
import './globals.css';

/**
 * `metadataBase` resolves the relative URLs below into absolute ones, which is
 * what every social crawler requires. It follows the deployment rather than
 * being hard-coded, so a preview deploy advertises itself and not production.
 */
const siteUrl =
  process.env.NEXT_PUBLIC_SITE_URL ??
  (process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : 'http://localhost:3210');

const description =
  'Your GitHub, Codeforces, LeetCode and AtCoder activity merged into a single streak, on your home screen.';

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: 'Widgeto — one streak, every platform',
    // Profile and leaderboard pages set their own name; this keeps the brand
    // on the end of it without every page repeating itself.
    template: '%s · Widgeto',
  },
  description,
  applicationName: 'Widgeto',
  openGraph: {
    type: 'website',
    siteName: 'Widgeto',
    title: 'Widgeto — one streak, every platform',
    description,
    url: '/',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Widgeto — one streak, every platform',
    description,
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=JetBrains+Mono:wght@400;500;700&family=Inter:wght@400;500;600;700&display=swap"
          rel="stylesheet"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
