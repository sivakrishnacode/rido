"use client";

import { useState } from "react";

import { presetRange } from "@/lib/heat";
import type { HeatmapMetric } from "@/lib/types";
import { useHeatmap } from "@/lib/use-heatmap";

import { HeatLayer } from "./heat-layer";

/** "Demand heat" background layer (last 30 days, street hexes), drawn under the service area and zones. */
export function HeatOverlay({ metric, opacity = 0.5 }: { metric: HeatmapMetric; opacity?: number }) {
  // Fixed window per mount so the query key is stable across renders.
  const [range] = useState(() => presetRange("30d"));
  const { data } = useHeatmap({ metric, ...range, resolution: 8 });
  return data ? <HeatLayer cells={data.cells} opacity={opacity} zIndex={0} /> : null;
}
