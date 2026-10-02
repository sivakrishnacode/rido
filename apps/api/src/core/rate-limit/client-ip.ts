import { isIP } from 'node:net';

/** What [clientIp] reads from an HTTP request (Express or a plain Node request). */
export interface IpRequest {
  readonly headers: Record<string, string | string[] | undefined>;
  readonly socket?: { readonly remoteAddress?: string };
  readonly ip?: string;
}

/** `::ffff:10.0.0.5` → `10.0.0.5` (IPv4-mapped IPv6, how Node reports IPv4 peers on a dual-stack socket). */
function unmapped(addr: string): string {
  return addr.trim().replace(/^::ffff:(?=\d+\.\d+\.\d+\.\d+$)/i, '');
}

/** 127.0.0.0/8 or ::1: this machine (or this container). */
export function isLoopback(addr: string): boolean {
  const a = unmapped(addr);
  return (isIP(a) === 4 && a.startsWith('127.')) || a === '::1';
}

/**
 * Loopback, private (10/8, 172.16/12, 192.168/16, fc00::/7) or link-local (169.254/16, fe80::/10): never a phone on
 * the internet, so a hop like this is our own reverse proxy (Caddy in Docker) or the admin server.
 */
export function isPrivateAddress(addr: string): boolean {
  const a = unmapped(addr);
  if (isIP(a) === 4) {
    const [x, y] = a.split('.').map(Number);
    return x === 127 || x === 10 || (x === 172 && y >= 16 && y <= 31) || (x === 192 && y === 168) || (x === 169 && y === 254);
  }
  if (isIP(a) === 6) {
    const l = a.toLowerCase();
    return l === '::1' || /^f[cd][0-9a-f]{0,2}:/.test(l) || /^fe[89ab][0-9a-f]?:/.test(l);
  }
  return false;
}

function forwardedFor(req: IpRequest): string[] {
  const xff = req.headers['x-forwarded-for'];
  return (Array.isArray(xff) ? xff.join(',') : (xff ?? '')).split(',').map(unmapped).filter((h) => isIP(h) !== 0);
}

function peerOf(req: IpRequest): string {
  return unmapped(req.socket?.remoteAddress ?? req.ip ?? '');
}

/**
 * The caller's IP. X-Forwarded-For is believed only when the socket peer is loopback or private (Caddy in Docker,
 * the admin server): port 3000 is reachable directly, so anyone else could put any address there. Read from the
 * right, skipping private hops (our own proxies), the first public address is the client; all private (dev, tests)
 * → the first one. Otherwise the socket's own address.
 */
export function clientIp(req: IpRequest): string {
  const peer = peerOf(req);
  if (!isPrivateAddress(peer)) return peer || 'unknown';
  const hops = forwardedFor(req);
  for (let i = hops.length - 1; i >= 0; i--) if (!isPrivateAddress(hops[i])) return hops[i];
  return hops[0] ?? (peer || 'unknown');
}

/**
 * A request from this machine itself with no forwarded client (a local script, the tests, an emulator through
 * 10.0.2.2): there is no outside caller to limit by IP. Per-user limits still apply.
 */
export function isFromSelf(req: IpRequest): boolean {
  return isLoopback(peerOf(req)) && forwardedFor(req).length === 0;
}
