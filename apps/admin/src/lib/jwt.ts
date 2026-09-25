/** Claims the Rido API puts in its JWT (apps/api/src/core/auth/auth-user.ts). */
export interface JwtClaims {
  readonly sub?: string;
  readonly role?: string;
  readonly exp?: number;
}

/**
 * Reads the JWT payload WITHOUT verifying the signature. Only used for optimistic checks (expiry, role) in
 * the proxy; the API verifies every request.
 */
export function decodeJwt(token: string): JwtClaims | null {
  const part = token.split(".")[1];
  if (!part) return null;
  try {
    const b64 = part.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(part.length / 4) * 4, "=");
    return JSON.parse(atob(b64)) as JwtClaims;
  } catch {
    return null;
  }
}

/** True when the token is unreadable, not an ADMIN token, or past its expiry. */
export function isUsableAdminToken(token: string | undefined, nowSeconds = Date.now() / 1000): boolean {
  if (!token) return false;
  const claims = decodeJwt(token);
  if (!claims || claims.role !== "ADMIN") return false;
  return typeof claims.exp !== "number" || claims.exp > nowSeconds;
}
