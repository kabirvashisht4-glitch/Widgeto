'use client';

import { useEffect, useState } from 'react';

/**
 * Whether the viewer is in a dark colour scheme.
 *
 * Deliberately reports `true` on the server and on the first client render,
 * then corrects itself after mount. The contribution grid mixes its colours in
 * JavaScript and writes them into `fill` attributes, so if the two renders
 * disagreed React would refuse to reconcile them. Dark is the honest default
 * here — it is what the design is built around.
 */
export function usePrefersDark(): boolean {
  const [dark, setDark] = useState(true);

  useEffect(() => {
    const query = window.matchMedia('(prefers-color-scheme: dark)');
    const sync = () => setDark(query.matches);
    sync();
    query.addEventListener('change', sync);
    return () => query.removeEventListener('change', sync);
  }, []);

  return dark;
}

/** The two colours the grid mixes toward, per theme. */
export function gridColors(dark: boolean) {
  return dark
    ? { empty: [26, 30, 38] as const, ground: [12, 14, 18] as const }
    : { empty: [235, 237, 240] as const, ground: [255, 255, 255] as const };
}
