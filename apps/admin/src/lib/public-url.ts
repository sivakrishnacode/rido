/**
 * An absolute URL on the admin's public address, for redirects. Behind Caddy, `request.url` is the container's own
 * address (`0.0.0.0:3001`), so use the Host / X-Forwarded-* headers the proxy passes on.
 */
export function publicUrl(request: { headers: Headers; url: string }, path: string): URL {
  const fallback = new URL(request.url);
  const host = request.headers.get("x-forwarded-host") ?? request.headers.get("host") ?? fallback.host;
  const proto = (request.headers.get("x-forwarded-proto") ?? fallback.protocol.replace(":", "")).split(",")[0].trim();
  return new URL(path, `${proto}://${host}`);
}

/**
 * A request another site made the browser send (an image or link on another site), by Sec-Fetch-Site. Same-origin
 * pages, redirects from them and a typed address ("none") are not; neither are old browsers without the header.
 */
export function isCrossSiteRequest(headers: Headers): boolean {
  const site = headers.get("sec-fetch-site");
  return site !== null && site !== "same-origin" && site !== "none";
}
