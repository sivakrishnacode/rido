"use client";

import { useMap } from "@vis.gl/react-google-maps";
import { useEffect, useMemo, useRef } from "react";

import { ZoneLabels } from "@/components/map/editor/zone-labels";
import { hexBoundary } from "@/lib/hex";
import type { DemandCell } from "@/lib/types";

export interface DemandHover {
  readonly cell: DemandCell;
  readonly x: number;
  readonly y: number;
}

/** Busy = amber, high = coral → red by multiplier; normal cells are not drawn. */
export function demandColor(c: Pick<DemandCell, "level" | "multiplier">): string {
  if (c.level === "busy") return "#F59E0B";
  return c.multiplier >= 1.3 ? "#B91C1C" : "#D84315";
}

/** Live demand vs free drivers per res-7 hexagon (GET /admin/demand), with "1.2×" labels on surging cells. */
export function DemandLayer({ cells, onHover }: { cells: readonly DemandCell[]; onHover?: (h: DemandHover | null) => void }) {
  const map = useMap();
  const layer = useRef<google.maps.Data | null>(null);
  const hover = useRef(onHover);
  useEffect(() => {
    hover.current = onHover;
  });
  const shown = useMemo(() => cells.filter((c) => c.level !== "normal"), [cells]);
  const byId = useMemo(() => new Map(shown.map((c) => [c.cell, c])), [shown]);
  const byIdRef = useRef(byId);

  useEffect(() => {
    if (!map) return;
    const data = new google.maps.Data({ map });
    layer.current = data;
    data.setStyle((f) => {
      const c = byIdRef.current.get(String(f.getId()));
      const color = c ? demandColor(c) : "#F59E0B";
      return { clickable: true, fillColor: color, fillOpacity: c?.level === "high" ? 0.38 : 0.28, strokeColor: color, strokeWeight: 1.5, zIndex: 4 };
    });
    const ls = [
      data.addListener("mouseover", (e: google.maps.Data.MouseEvent) => {
        const c = byIdRef.current.get(String(e.feature.getId()));
        const dom = e.domEvent as MouseEvent | undefined;
        const rect = map.getDiv()?.getBoundingClientRect();
        if (c) hover.current?.({ cell: c, x: dom && rect ? dom.clientX - rect.left : 0, y: dom && rect ? dom.clientY - rect.top : 0 });
      }),
      data.addListener("mouseout", () => hover.current?.(null)),
    ];
    return () => {
      ls.forEach((l) => l?.remove());
      data.setMap(null);
      layer.current = null;
    };
  }, [map]);

  useEffect(() => {
    byIdRef.current = byId;
    const data = layer.current;
    if (!data) return;
    data.forEach((f) => data.remove(f));
    data.addGeoJson({
      type: "FeatureCollection",
      features: shown.map((c) => {
        const ring = hexBoundary(c.cell).map(([lat, lng]) => [lng, lat]);
        ring.push(ring[0]);
        return { type: "Feature", id: c.cell, properties: {}, geometry: { type: "Polygon", coordinates: [ring] } };
      }),
    });
  }, [map, shown, byId]);

  const labels = useMemo(
    () =>
      shown
        .filter((c) => c.multiplier > 1)
        .map((c) => ({
          id: c.cell,
          lat: c.lat,
          lng: c.lng,
          text: `${Number(c.multiplier.toFixed(2))}×`,
          title: `${c.requests} bookings · ${c.freeDrivers} free drivers · ratio ${c.ratio} · ${c.multiplier.toFixed(2)}×`,
          color: demandColor(c),
          priority: c.multiplier * 1000 + c.requests,
        })),
    [shown],
  );

  return <ZoneLabels labels={labels} minZoom={10} />;
}
