import type { Metadata } from "next";

import { PageHeader } from "@/components/common/page";
import { adminApi } from "@/lib/api";

import { LiveView } from "./live-view";

export const metadata: Metadata = { title: "Live" };

export default async function LivePage() {
  const [live, cities] = await Promise.all([adminApi.live(), adminApi.cities()]);
  return (
    <>
      <PageHeader title="Live" description="Online drivers and active trips, refreshed every 10 seconds." />
      <LiveView
        initial={live}
        cities={cities.filter((c) => c.isActive).map((c) => ({ id: c.id, name: c.name, centerLat: c.centerLat, centerLng: c.centerLng }))}
      />
    </>
  );
}
