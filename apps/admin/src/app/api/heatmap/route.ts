import { NextResponse, type NextRequest } from "next/server";

import { apiBaseUrl, apiUrl } from "@/lib/api-core";
import { getToken } from "@/lib/session";

const ALLOWED = ["metric", "from", "to", "kind", "vehicleKind", "hourFrom", "hourTo", "resolution"] as const;

/** Browser-side heatmap filters → GET /v1/admin/heatmap with the admin cookie (JWT stays server side). */
export async function GET(request: NextRequest) {
  const token = await getToken();
  if (!token) return NextResponse.json({ message: "Signed out" }, { status: 401 });
  const query: Record<string, string> = {};
  for (const k of ALLOWED) {
    const v = request.nextUrl.searchParams.get(k);
    if (v) query[k] = v;
  }
  try {
    const res = await fetch(apiUrl(apiBaseUrl(), "/admin/heatmap", query), { headers: { authorization: `Bearer ${token}` }, cache: "no-store" });
    const body = await res.json().catch(() => null);
    if (res.status === 401) return NextResponse.json({ message: "Session expired" }, { status: 401 });
    if (!res.ok) return NextResponse.json({ message: (body as { message?: unknown })?.message ?? `Heatmap failed (${res.status})` }, { status: res.status });
    return NextResponse.json(body, { headers: { "cache-control": "no-store" } });
  } catch {
    return NextResponse.json({ message: "Cannot reach the Rido API" }, { status: 503 });
  }
}
