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
