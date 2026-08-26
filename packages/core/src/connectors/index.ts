/**
 * Connector registry.
 *
 * Adding a platform means adding one file that returns a `PlatformResult` and
 * one line here. Nothing downstream — streak engine, API, widget — changes.
 */
import type { FetchContext, PlatformId, PlatformResult } from '../types.ts';
import { fetchGitHub } from './github.ts';
import { fetchLeetCode } from './leetcode.ts';
import { fetchCodeforces } from './codeforces.ts';

export type Connector = (handle: string, ctx: FetchContext) => Promise<PlatformResult>;

export interface ConnectorMeta {
  id: PlatformId;
  name: string;
  /** Brand colour, used by the widget and the site. */
  color: string;
  /** Where the handle comes from, shown as placeholder text at onboarding. */
  handleHint: string;
  /**
   * `official` sources we can lean on; `unofficial` ones we treat as
   * best-effort and are upfront about in the UI.
   */
  support: 'official' | 'unofficial';
  fetch: Connector;
}

export const CONNECTORS: Record<PlatformId, ConnectorMeta> = {
  github: {
    id: 'github',
    name: 'GitHub',
    color: '#39d353',
    handleHint: 'torvalds',
    support: 'official',
    fetch: fetchGitHub,
  },
  codeforces: {
    id: 'codeforces',
    name: 'Codeforces',
    color: '#1f8acb',
    handleHint: 'tourist',
    support: 'official',
    fetch: fetchCodeforces,
  },
  leetcode: {
    id: 'leetcode',
    name: 'LeetCode',
    color: '#ffa116',
    handleHint: 'lee215',
    support: 'unofficial',
    fetch: fetchLeetCode,
  },
};

export const PLATFORM_IDS = Object.keys(CONNECTORS) as PlatformId[];
