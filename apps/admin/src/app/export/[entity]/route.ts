import { NextResponse, type NextRequest } from "next/server";

import { apiBaseUrl, apiUrl } from "@/lib/api-core";
import { getToken } from "@/lib/session";

const ENTITIES = new Set(["trips", "drivers", "payments"]);

/** Streams GET /admin/export/{trips|drivers|payments}.csv from the API with the admin's token. */
export async function GET(request: NextRequest, ctx: RouteContext<"/export/[entity]">) {
  const { entity } = await ctx.params;
  if (!ENTITIES.has(entity)) return NextResponse.json({ message: "Unknown export" }, { status: 404 });
  const token = await getToken();
  if (!token) return NextResponse.redirect(new URL("/login", request.url));

  let res: Response;
  try {
    res = await fetch(apiUrl(apiBaseUrl(), `/admin/export/${entity}.csv`), {
      headers: { authorization: `Bearer ${token}` },
      cache: "no-store",
    });
  } catch {
    return NextResponse.json({ message: "Cannot reach the Rido API" }, { status: 503 });
  }
  if (res.status === 401) return NextResponse.redirect(new URL("/auth/signout?expired=1", request.url));
  if (!res.ok || !res.body) return NextResponse.json({ message: `Export failed (${res.status})` }, { status: res.status });

  const day = new Date().toISOString().slice(0, 10);
  return new Response(res.body, {
    headers: {
      "content-type": "text/csv; charset=utf-8",
      "content-disposition": `attachment; filename="rido-${entity}-${day}.csv"`,
      "cache-control": "no-store",
    },
  });
}
