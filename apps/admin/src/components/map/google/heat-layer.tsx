"use client";

import { useMap } from "@vis.gl/react-google-maps";
import { useEffect, useMemo, useRef } from "react";

import { heatColor } from "@/lib/heat";
import { hexBoundary } from "@/lib/hex";
import type { HeatCell } from "@/lib/types";

export interface HeatHover {
  readonly cell: HeatCell;
  readonly rank: number;
  readonly x: number;
  readonly y: number;
}

/**
 * H3 choropleth on a google.maps.Data layer: fill by intensity on the heat ramp. GeoJSON is memoised per data set;
 * [interactive] adds hover (tooltip callback) and click / shift-click selection.
 */
export function HeatLayer({
  cells,
  opacity = 0.65,
  zIndex = 0,
  interactive = false,
  selected,
  outside,
  onHover,
  onClick,
}: {
  cells: readonly HeatCell[];
  opacity?: number;
  zIndex?: number;
  interactive?: boolean;
  selected?: ReadonlySet<string>;
  /** Cells outside every service area: thicker amber border. */
  outside?: ReadonlySet<string>;
  onHover?: (h: HeatHover | null) => void;
  onClick?: (cell: string, isAdditive: boolean) => void;
}) {
  const map = useMap();
  const layer = useRef<google.maps.Data | null>(null);
  const handlers = useRef({ onHover, onClick });
  useEffect(() => {
    handlers.current = { onHover, onClick };
  });

  const geojson = useMemo(
    () => ({
      type: "FeatureCollection",
      features: cells.map((c, i) => {
        const ring = hexBoundary(c.cell).map(([lat, lng]) => [lng, lat]);
        ring.push(ring[0]);
        return {
          type: "Feature",
          id: c.cell,
          properties: { value: c.value, intensity: c.intensity, rank: i + 1 },
          geometry: { type: "Polygon", coordinates: [ring] },
        };
      }),
    }),
    [cells],
  );

  useEffect(() => {
    if (!map) return;
    const data = new google.maps.Data({ map });
    layer.current = data;
    const listeners = interactive
      ? [
          data.addListener("mouseover", (e: google.maps.Data.MouseEvent) => {
            const f = e.feature;
            const dom = e.domEvent as MouseEvent | undefined;
            const rect = map.getDiv()?.getBoundingClientRect();
            handlers.current.onHover?.({
              cell: { cell: String(f.getId()), value: Number(f.getProperty("value")), intensity: Number(f.getProperty("intensity")) },
              rank: Number(f.getProperty("rank")),
              x: dom && rect ? dom.clientX - rect.left : 0,
              y: dom && rect ? dom.clientY - rect.top : 0,
            });
          }),
          data.addListener("mouseout", () => handlers.current.onHover?.(null)),
          data.addListener("click", (e: google.maps.Data.MouseEvent) => {
            const dom = e.domEvent as MouseEvent | undefined;
            handlers.current.onClick?.(String(e.feature.getId()), !!dom?.shiftKey);
          }),
        ]
      : [];
    return () => {
      listeners.forEach((l) => l?.remove());
      data.setMap(null);
      layer.current = null;
    };
  }, [map, interactive]);

  useEffect(() => {
    const data = layer.current;
    if (!data) return;
    data.forEach((f) => data.remove(f));
    if (geojson.features.length > 0) data.addGeoJson(geojson);
  }, [map, interactive, geojson]);

  useEffect(() => {
    layer.current?.setStyle((f) => {
      const id = String(f.getId());
      const isSelected = selected?.has(id);
      const isOutside = outside?.has(id);
      return {
        clickable: interactive,
        cursor: interactive ? "pointer" : undefined,
        fillColor: heatColor(Number(f.getProperty("intensity"))),
        fillOpacity: opacity,
        strokeColor: isSelected ? "#1E293B" : isOutside ? "#F59E0B" : "#FFFFFF",
        strokeOpacity: isSelected || isOutside ? 1 : 0.6,
        strokeWeight: isSelected ? 3 : isOutside ? 2.5 : 0.6,
        zIndex: isSelected ? zIndex + 2 : isOutside ? zIndex + 1 : zIndex,
      };
    });
  }, [map, interactive, geojson, selected, outside, opacity, zIndex]);

  return null;
}
