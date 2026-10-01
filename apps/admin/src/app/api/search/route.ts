import { NextResponse, type NextRequest } from "next/server";

import { apiBaseUrl, apiUrl } from "@/lib/api-core";
import { getToken } from "@/lib/session";

/** Global search for the Ctrl+K palette: GET /v1/admin/search with the admin's token. Admins only. */
export async function GET(request: NextRequest) {
  const token = await getToken();
  if (!token) return NextResponse.json({ message: "Signed out" }, { status: 401 });
  const q = request.nextUrl.searchParams.get("q")?.trim() ?? "";
  if (q.length < 2) return NextResponse.json({ drivers: [], people: [], trips: [] });
  try {
    const res = await fetch(apiUrl(apiBaseUrl(), "/admin/search", { q: q.slice(0, 60) }), {
      headers: { authorization: `Bearer ${token}` },
      cache: "no-store",
      signal: AbortSignal.timeout(8_000),
    });
    if (res.status === 401) return NextResponse.json({ message: "Signed out" }, { status: 401 });
    if (!res.ok) return NextResponse.json({ message: `Search failed (${res.status})` }, { status: 502 });
    return NextResponse.json(await res.json());
  } catch {
    return NextResponse.json({ message: "Cannot reach the Tamil Taxi API" }, { status: 503 });
  }
}
