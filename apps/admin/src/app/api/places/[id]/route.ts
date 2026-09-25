import { NextResponse, type NextRequest } from "next/server";

import { apiBaseUrl, apiUrl } from "@/lib/api-core";
import { getToken } from "@/lib/session";

/** Place details (lat/lng) for a search result: GET /v1/places/details/:placeId, ending the autocomplete session. */
export async function GET(request: NextRequest, ctx: RouteContext<"/api/places/[id]">) {
  if (!(await getToken())) return NextResponse.json({ message: "Signed out" }, { status: 401 });
  const { id } = await ctx.params;
  const session = request.nextUrl.searchParams.get("session") ?? undefined;
  try {
    const res = await fetch(apiUrl(apiBaseUrl(), `/places/details/${encodeURIComponent(id)}`, { session }), { cache: "no-store" });
    if (!res.ok) return NextResponse.json({ message: `Lookup failed (${res.status})` }, { status: 502 });
    const place = (await res.json()) as unknown;
    if (!place) return NextResponse.json({ message: "Place not found" }, { status: 404 });
    return NextResponse.json(place);
  } catch {
    return NextResponse.json({ message: "Cannot reach the Rido API" }, { status: 503 });
  }
}
