import { NextResponse, type NextRequest } from "next/server";

import { clearSession } from "@/lib/session";

/**
 * Clears the session cookies and returns to /login. Used when the API rejects the token while a page is
 * rendering (Server Components cannot change cookies themselves).
 */
export async function GET(request: NextRequest) {
  await clearSession();
  const url = new URL("/login", request.url);
  if (request.nextUrl.searchParams.get("expired")) url.searchParams.set("expired", "1");
  return NextResponse.redirect(url);
}
