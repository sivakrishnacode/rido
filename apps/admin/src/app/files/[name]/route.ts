import { NextResponse, type NextRequest } from "next/server";

import { apiBaseUrl, apiUrl } from "@/lib/api-core";
import { getToken } from "@/lib/session";

/** Streams a KYC document from GET /admin/files/:name with the admin's token (files are never public). */
export async function GET(request: NextRequest, ctx: RouteContext<"/files/[name]">) {
  const { name } = await ctx.params;
  const token = await getToken();
  if (!token) return NextResponse.redirect(new URL("/login", request.url));

  let res: Response;
  try {
    res = await fetch(apiUrl(apiBaseUrl(), `/admin/files/${encodeURIComponent(name)}`), {
      headers: { authorization: `Bearer ${token}` },
      cache: "no-store",
    });
  } catch {
    return NextResponse.json({ message: "Cannot reach the Rido API" }, { status: 503 });
  }
  if (res.status === 401) return NextResponse.redirect(new URL("/auth/signout?expired=1", request.url));
  if (!res.ok || !res.body) return NextResponse.json({ message: "File not found" }, { status: res.status });

  return new Response(res.body, {
    headers: {
      "content-type": res.headers.get("content-type") ?? "application/octet-stream",
      "content-disposition": "inline",
      "cache-control": "private, no-store",
    },
  });
}
