import { NextResponse, type NextRequest } from "next/server";

import { apiBaseUrl, apiUrl } from "@/lib/api-core";
import { getToken } from "@/lib/session";

/** Live demand vs supply for the Live map: GET /v1/admin/demand[?refresh=true] with the admin cookie. */
export async function GET(request: NextRequest) {
  const token = await getToken();
  if (!token) return NextResponse.json({ message: "Signed out" }, { status: 401 });
  const refresh = request.nextUrl.searchParams.get("refresh") === "true" ? "true" : undefined;
  try {
    const res = await fetch(apiUrl(apiBaseUrl(), "/admin/demand", { refresh }), { headers: { authorization: `Bearer ${token}` }, cache: "no-store" });
    if (res.status === 401) return NextResponse.json({ message: "Session expired" }, { status: 401 });
    if (!res.ok) return NextResponse.json({ message: `Demand failed (${res.status})` }, { status: 502 });
    return NextResponse.json(await res.json(), { headers: { "cache-control": "no-store" } });
  } catch {
    return NextResponse.json({ message: "Cannot reach the Rido API" }, { status: 503 });
  }
}
