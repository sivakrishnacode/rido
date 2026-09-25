import type { Metadata } from "next";

import { PageHeader } from "@/components/common/page";
import { adminApi } from "@/lib/api";
import { presetRange } from "@/lib/heat";

import { HeatmapView } from "./heatmap-view";

export const metadata: Metadata = { title: "Heatmap" };

export default async function HeatmapPage() {
  const [initial, cities] = await Promise.all([adminApi.heatmap({ metric: "pickups", ...presetRange("30d") }), adminApi.cities()]);
  return (
    <>
      <PageHeader
        title="Heatmap"
        description="Where trips start, end, earn and go unserved, per H3 hexagon from real trips. Turn hot spots into zones or service area."
      />
      <HeatmapView
        initial={initial}
        cities={cities
          .filter((c) => c.isActive)
          .map((c) => ({ id: c.id, name: c.name, h3Resolution: c.h3Resolution, centerLat: c.centerLat, centerLng: c.centerLng, serviceCells: c.serviceCells }))}
      />
    </>
  );
}
