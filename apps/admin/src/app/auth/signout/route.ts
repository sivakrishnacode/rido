import { NextResponse, type NextRequest } from "next/server";

import { clearSession } from "@/lib/session";
import { isCrossSiteRequest, publicUrl } from "@/lib/public-url";

/**
 * Clears the session cookies and returns to /login. Used when the API rejects the token while a page is
 * rendering (Server Components cannot change cookies themselves). Only from this site's own pages and redirects:
 * another site linking here (an image tag) must not sign the admin out.
 */
export async function GET(request: NextRequest) {
  if (isCrossSiteRequest(request.headers)) return NextResponse.redirect(publicUrl(request, "/"));
  await clearSession();
  const url = publicUrl(request, "/login");
  if (request.nextUrl.searchParams.get("expired")) url.searchParams.set("expired", "1");
  if (request.nextUrl.searchParams.get("blocked")) url.searchParams.set("blocked", "1");
  return NextResponse.redirect(url);
}
