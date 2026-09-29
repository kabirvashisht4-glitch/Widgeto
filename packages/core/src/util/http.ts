/** Shared fetch helpers: timeouts, retries, and honest error messages. */

export class ConnectorError extends Error {
  retryable: boolean;
  constructor(message: string, retryable = false) {
    super(message);
    this.name = 'ConnectorError';
    this.retryable = retryable;
  }
}

export interface RequestOptions extends RequestInit {
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
  /** Attempts for retryable failures (429/5xx/network). */
  retries?: number;
}

/**
 * `fetch` with a timeout and bounded exponential backoff.
 *
 * Backoff matters more than usual here: two of the three connectors run on
 * endpoints we are guests on, and hammering them is how a widget app gets
 * itself Cloudflare-blocked for every user at once.
 */
export async function request(url: string, opts: RequestOptions = {}): Promise<Response> {
  const { timeoutMs = 12_000, fetchImpl = fetch, retries = 2, ...init } = opts;

  let lastError: Error = new ConnectorError('request never ran');

  for (let attempt = 0; attempt <= retries; attempt++) {
    if (attempt > 0) {
      // 400ms, 800ms, ... with jitter so retries from many users disperse.
      const backoff = 400 * 2 ** (attempt - 1) * (0.75 + Math.random() * 0.5);
      await new Promise((r) => setTimeout(r, backoff));
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const res = await fetchImpl(url, { ...init, signal: controller.signal });
      if (res.status === 429 || res.status >= 500) {
        // These messages reach a real person on a widget, so they say what is
        // wrong and whether waiting will fix it. "upstream returned 429" tells
        // them nothing they can act on.
        lastError = new ConnectorError(describeStatus(res, url), true);
        continue;
      }
      return res;
    } catch (err) {
      const aborted = err instanceof Error && err.name === 'AbortError';
      lastError = new ConnectorError(
        aborted ? `timed out after ${timeoutMs}ms` : `network error: ${(err as Error).message}`,
        true,
      );
    } finally {
      clearTimeout(timer);
    }
  }

  throw lastError;
}

/** The host, for a message that names who is refusing rather than "upstream". */
function hostOf(url: string): string {
  try {
    return new URL(url).host.replace(/^www\./, '');
  } catch {
    return 'the upstream service';
  }
}

/**
 * Turn a status into something a person reading a widget can act on.
 *
 * A rate limit and an outage need different reactions — wait a bit versus wait
 * a while — and neither is conveyed by the number alone. `Retry-After`, when
 * the service sends it, is the only precise answer available.
 */
function describeStatus(res: Response, url: string): string {
  const host = hostOf(url);

  if (res.status === 429) {
    const after = Number(res.headers.get('retry-after'));
    return Number.isFinite(after) && after > 0
      ? `${host} is rate limiting us — try again in about ${after}s`
      : `${host} is rate limiting us — try again shortly`;
  }

  if (res.status === 503) return `${host} is unavailable right now`;
  return `${host} is having trouble (HTTP ${res.status})`;
}

export async function postJson<T>(url: string, body: unknown, opts: RequestOptions = {}): Promise<T> {
  const res = await request(url, {
    ...opts,
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(opts.headers ?? {}) },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new ConnectorError(`upstream returned ${res.status}`);
  return (await res.json()) as T;
}

export async function getJson<T>(url: string, opts: RequestOptions = {}): Promise<T> {
  const res = await request(url, opts);
  if (!res.ok) throw new ConnectorError(`upstream returned ${res.status}`);
  return (await res.json()) as T;
}
