import { NextResponse, type NextRequest } from "next/server";

import { isUsableAdminToken } from "@/lib/jwt";

// Keep in sync with src/lib/session.ts (that module is server-only and uses next/headers).
const TOKEN_COOKIE = "rido_admin_token";
const USER_COOKIE = "rido_admin_user";

/**
 * Optimistic auth check (Next 16 proxy, formerly middleware): no usable admin cookie → /login.
 * The API still verifies the JWT on every call; a 401 there also signs the admin out.
 */
export function proxy(request: NextRequest) {
  const { pathname, search } = request.nextUrl;
  const token = request.cookies.get(TOKEN_COOKIE)?.value;
  const isSignedIn = isUsableAdminToken(token);
  const isLogin = pathname === "/login";

  if (isLogin && isSignedIn) return NextResponse.redirect(new URL("/", request.url));
  if (isLogin || isSignedIn) return NextResponse.next();

  const url = new URL("/login", request.url);
  if (pathname !== "/") url.searchParams.set("next", `${pathname}${search}`);
  if (token) url.searchParams.set("expired", "1");
  const res = NextResponse.redirect(url);
  if (token) {
    res.cookies.delete(TOKEN_COOKIE);
    res.cookies.delete(USER_COOKIE);
  }
  return res;
}

export const config = {
  // Everything except Next internals, JSON route handlers (they answer 401 themselves), sign-out and static files.
  matcher: ["/((?!_next/|api/|auth/signout|favicon.ico|icon.svg|.*\\.(?:png|jpg|jpeg|svg|webp|ico|txt)$).*)"],
};
