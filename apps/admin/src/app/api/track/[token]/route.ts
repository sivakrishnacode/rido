import { NextResponse, type NextRequest } from "next/server";

import { fetchShare, viewerIp } from "@/lib/track-server";

/** Public polling endpoint of the live trip page: forwards to GET /v1/share/:token with the viewer's IP. */
export async function GET(request: NextRequest, ctx: RouteContext<"/api/track/[token]">) {
  const { token } = await ctx.params;
  const result = await fetchShare(token, viewerIp(request.headers));
  return NextResponse.json(result, { headers: { "cache-control": "no-store" } });
}
