import type { Metadata } from "next";

import { LinkTabs } from "@/components/common/link-tabs";
import { PageHeader } from "@/components/common/page";
import { adminApi, placeNameAt } from "@/lib/api";
import { formatCount } from "@/lib/format";
import { cellCentre } from "@/lib/hex";
import { param, withQuery } from "@/lib/paging";
import { HEX_STAT_RES, type HexStatRes, type HexStatsSort } from "@/lib/types";

import { SpeedsView } from "./speeds-view";

export const metadata: Metadata = { title: "Travel speeds" };

const RES_LABEL: Record<HexStatRes, string> = { 9: "Street · res 9", 8: "Neighbourhood · res 8", 7: "District · res 7" };

const SORTS: readonly HexStatsSort[] = ["busiest", "slowest", "fastest"];

export default async function TravelSpeedsPage({ searchParams }: PageProps<"/travel-speeds">) {
  const sp = await searchParams;
  const r = Number(param(sp.res));
  const res = HEX_STAT_RES.find((x) => x === r) ?? 8;
  const h = param(sp.hour);
  const hour = h !== undefined && /^\d{1,2}$/.test(h) && Number(h) <= 23 ? Number(h) : undefined;
  const sort = SORTS.find((x) => x === param(sp.sort)) ?? "busiest";
  const used = param(sp.used) === "true";
  const [stats, settings] = await Promise.all([adminApi.hexStats({ res, hour, sort, used, limit: 50 }), adminApi.settings()]);
  // Names for every listed hex (reverse geocode of the fixed hex centre: cached by the API and here for a day).
  const cells = [...new Set(stats.top.flatMap((r) => [r.fromCell, r.toCell]))];
  const names = Object.fromEntries(
    await Promise.all(
      cells.map(async (c) => {
        const { lat, lng } = cellCentre(c);
        return [c, await placeNameAt(lat, lng)] as const;
      }),
    ),
  );
  return (
    <>
      <PageHeader
        title="Travel speeds"
        description="Hex-to-hex speeds learned from completed trips, by hour of day (IST), at three hex sizes. ETAs use the smallest hex pair with enough trips at that hour, then larger ones, then the all-day average."
      />
      <LinkTabs
        active={String(res)}
        tabs={HEX_STAT_RES.map((x) => ({
          value: String(x),
          label: RES_LABEL[x],
          href: withQuery("/travel-speeds", { res: x === 8 ? undefined : x, hour, sort: sort === "busiest" ? undefined : sort, used: used || undefined }),
          count: <span className="text-[11px] text-muted-foreground tabular-nums">{formatCount(stats.byRes[x])}</span>,
        }))}
      />
      <SpeedsView
        key={`${res}-${hour}-${sort}-${used}`}
        stats={stats}
        names={names}
        minTrips={Number(settings.historicalEtaMinTrips ?? 0)}
        filters={{ hour, sort, used }}
      />
    </>
  );
}
