"use client";

import { LiveMap } from "@/components/map/lazy";
import type { LiveData } from "@/lib/types";

/** Small, non-interactive-looking live map for the dashboard card. */
export function MiniLiveMap({ data, center }: { data: LiveData; center: [number, number] }) {
  return <LiveMap data={data} center={center} compact className="rounded-none" />;
}
