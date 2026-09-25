import { NextResponse, type NextRequest } from "next/server";

import { apiBaseUrl, apiUrl } from "@/lib/api-core";
import { getToken } from "@/lib/session";

/**
 * Browser polling endpoint for the Live page: forwards the httpOnly admin cookie to GET /admin/live
 * (and, with ?area=<cityId>, the public service area) so the JWT never reaches client JS.
 */
export async function GET(request: NextRequest) {
  const token = await getToken();
  if (!token) return NextResponse.json({ message: "Signed out" }, { status: 401 });
  const base = apiBaseUrl();
  const areaId = request.nextUrl.searchParams.get("area");
  try {
    const [live, area] = await Promise.all([
      fetch(apiUrl(base, "/admin/live"), { headers: { authorization: `Bearer ${token}` }, cache: "no-store" }),
      areaId ? fetch(apiUrl(base, `/cities/${encodeURIComponent(areaId)}/service-area`), { cache: "no-store" }) : null,
    ]);
    if (live.status === 401) return NextResponse.json({ message: "Session expired" }, { status: 401 });
    if (!live.ok) return NextResponse.json({ message: `Live data failed (${live.status})` }, { status: 502 });
    return NextResponse.json(
      { live: await live.json(), area: area?.ok ? await area.json() : null, at: new Date().toISOString() },
      { headers: { "cache-control": "no-store" } },
    );
  } catch {
    return NextResponse.json({ message: "Cannot reach the Rido API" }, { status: 503 });
  }
}
