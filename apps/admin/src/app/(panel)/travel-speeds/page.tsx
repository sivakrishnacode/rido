import type { Metadata } from "next";

import { PageHeader } from "@/components/common/page";
import { adminApi, placeNameAt } from "@/lib/api";
import { cellCentre } from "@/lib/hex";

import { SpeedsView } from "./speeds-view";

export const metadata: Metadata = { title: "Travel speeds" };

export default async function TravelSpeedsPage() {
  const [stats, settings] = await Promise.all([adminApi.hexStats(), adminApi.settings()]);
  // Names for the hexes in the first 20 pairs (reverse geocode, cached for a day).
  const cells = [...new Set(stats.top.slice(0, 20).flatMap((r) => [r.fromCell, r.toCell]))];
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
        description="Hex-to-hex speeds learned from completed trips, by hour of day (IST). Dispatch uses them for ETAs once a pair has enough trips."
      />
      <SpeedsView stats={stats} names={names} minTrips={Number(settings.historicalEtaMinTrips ?? 0)} />
    </>
  );
}
