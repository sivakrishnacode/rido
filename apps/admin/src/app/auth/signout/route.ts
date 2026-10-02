import { NextResponse, type NextRequest } from "next/server";

import { clearSession } from "@/lib/session";
import { publicUrl } from "@/lib/public-url";

/**
 * Clears the session cookies and returns to /login. Used when the API rejects the token while a page is
 * rendering (Server Components cannot change cookies themselves).
 */
export async function GET(request: NextRequest) {
  await clearSession();
  const url = publicUrl(request, "/login");
  if (request.nextUrl.searchParams.get("expired")) url.searchParams.set("expired", "1");
  if (request.nextUrl.searchParams.get("blocked")) url.searchParams.set("blocked", "1");
  return NextResponse.redirect(url);
}
