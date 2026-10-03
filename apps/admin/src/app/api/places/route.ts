import { NextResponse, type NextRequest } from "next/server";

import { apiBaseUrl, apiUrl } from "@/lib/api-core";
import { getToken } from "@/lib/session";

/** Admin map search: GET /v1/places/autocomplete (the API's Google server key + Redis cache). Admins only. */
export async function GET(request: NextRequest) {
  const token = await getToken();
  if (!token) return NextResponse.json({ message: "Signed out" }, { status: 401 });
  const q = request.nextUrl.searchParams.get("q")?.trim() ?? "";
  const session = request.nextUrl.searchParams.get("session") ?? "";
  // The API looks nothing up below 4 characters.
  if (q.length < 4) return NextResponse.json({ source: "local", results: [] });
  try {
    const res = await fetch(apiUrl(apiBaseUrl(), "/places/autocomplete", { q: q.slice(0, 80), session }), {
      cache: "no-store",
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) return NextResponse.json({ message: `Search failed (${res.status})` }, { status: 502 });
    return NextResponse.json(await res.json());
  } catch {
    return NextResponse.json({ message: "Cannot reach the Tamil Taxi API" }, { status: 503 });
  }
}
