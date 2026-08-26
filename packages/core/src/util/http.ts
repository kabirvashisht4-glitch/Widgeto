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
        lastError = new ConnectorError(`upstream returned ${res.status}`, true);
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
