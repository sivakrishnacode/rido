import "server-only";

import { apiBaseUrl, apiUrl } from "./api-core";
import { shareResult, type ShareResult } from "./track";

/**
 * Reads a public share link from the API (no admin session: anyone with the link may look). [forwardedFor] is the
 * viewer's IP chain, so the API rate limits each viewer rather than this server.
 */
export async function fetchShare(token: string, forwardedFor: string | null): Promise<ShareResult> {
  try {
    const res = await fetch(apiUrl(apiBaseUrl(), `/share/${encodeURIComponent(token)}`), {
      headers: { accept: "application/json", ...(forwardedFor ? { "x-forwarded-for": forwardedFor } : {}) },
      cache: "no-store",
      signal: AbortSignal.timeout(8_000),
    });
    const text = await res.text();
    let body: unknown = null;
    try {
      body = text ? JSON.parse(text) : null;
    } catch {
      body = null;
    }
    return shareResult(res.status, body);
  } catch {
    return { kind: "error", message: "Couldn't reach Rido. Retrying…" };
  }
}

/** The viewer's X-Forwarded-For chain (Caddy sets it), else the direct client address Next saw. */
export function viewerIp(headers: Headers): string | null {
  return headers.get("x-forwarded-for") ?? headers.get("x-real-ip");
}
