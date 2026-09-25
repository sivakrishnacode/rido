import { NextResponse, type NextRequest } from "next/server";

import { apiBaseUrl, apiUrl } from "@/lib/api-core";
import { getToken } from "@/lib/session";

/** Admin map search: GET /v1/places/autocomplete (the API's Google server key + Redis cache). Admins only. */
export async function GET(request: NextRequest) {
  if (!(await getToken())) return NextResponse.json({ message: "Signed out" }, { status: 401 });
  const q = request.nextUrl.searchParams.get("q")?.trim() ?? "";
  const session = request.nextUrl.searchParams.get("session") ?? "";
  if (q.length < 3) return NextResponse.json({ source: "local", results: [] });
  try {
    const res = await fetch(apiUrl(apiBaseUrl(), "/places/autocomplete", { q: q.slice(0, 80), session }), { cache: "no-store" });
    if (!res.ok) return NextResponse.json({ message: `Search failed (${res.status})` }, { status: 502 });
    return NextResponse.json(await res.json());
  } catch {
    return NextResponse.json({ message: "Cannot reach the Rido API" }, { status: 503 });
  }
}
