"use client";

import { Loader2Icon, SaveIcon, Trash2Icon } from "lucide-react";
import { useMemo, useState, useTransition } from "react";
import { toast } from "sonner";

import { HexMap, type HexLayerDef } from "@/components/map/lazy";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { formatCount } from "@/lib/format";
import { applyCells, circleCells } from "@/lib/hex";
import type { CityDetail } from "@/lib/types";
import { cellsToKm2 } from "@/lib/validation";

import { saveServiceCells } from "../../actions";
import { PaintToolbar } from "./paint-tools";
import { useCellEditor } from "./use-cell-editor";

const NO_EXCLUDE: ReadonlySet<string> = new Set();

export const SERVICE_STYLE = { color: "#D84315", fillColor: "#F4511E", fillOpacity: 0.22, weight: 0.6, opacity: 0.8 } as const;

function sameCells(a: readonly string[], b: readonly string[]): boolean {
  return a.length === b.length && a.every((c, i) => c === b[i]);
}

/** Tab a) paint the city's H3 service area and save it → PUT /admin/cities/:id/service-cells. */
export function ServiceAreaEditor({ city }: { city: CityDetail }) {
  const saved = useMemo(() => [...city.serviceCells].sort(), [city.serviceCells]);
  const [baseline, setBaseline] = useState(saved);
  const ed = useCellEditor(saved);
  const [centre, setCentre] = useState<{ lat: number; lng: number }>({ lat: city.centerLat, lng: city.centerLng });
  const [radius, setRadius] = useState("3");
  const [ghostState, setGhostState] = useState<"ok" | "zoom-in">("ok");
  const [isPending, startTransition] = useTransition();
  const isDirty = !sameCells(ed.cells, baseline);
  const radiusN = Number(radius);

  const layers: HexLayerDef[] = [
    { id: "service", cells: ed.cells, style: SERVICE_STYLE },
    // Zones for context (outline only).
    ...city.zones.map((z) => ({ id: `z-${z.id}`, cells: z.cells, style: { color: z.color, fillOpacity: 0, weight: 1.2, opacity: 0.7 } })),
  ];

  function fillCircle(mode: "add" | "remove") {
    if (!(radiusN > 0 && radiusN <= 60)) {
      toast.error("Radius must be between 0 and 60 km");
      return;
    }
    ed.commit(applyCells(ed.cells, circleCells(centre.lat, centre.lng, radiusN, city.h3Resolution), mode));
  }

  return (
    <div className="grid gap-4 lg:grid-cols-[1fr_300px]">
      <Card className="gap-0 overflow-hidden p-0">
        <div className="flex flex-wrap items-center gap-2 border-b px-3 py-2">
          <PaintToolbar
            tool={ed.tool}
            onTool={ed.setTool}
            canUndo={ed.canUndo}
            canRedo={ed.canRedo}
            onUndo={ed.undo}
            onRedo={ed.redo}
          />
          <span className="ml-auto text-xs text-muted-foreground">
            {ghostState === "zoom-in" ? "Zoom in to paint new hexagons" : "Grey hexagons are outside the service area"}
          </span>
        </div>
        <div className="h-[62vh] min-h-96">
          <HexMap
            center={[city.centerLat, city.centerLng]}
            resolution={city.h3Resolution}
            layers={layers}
            fitCells={saved}
            paint={ed.paint}
            onPick={ed.tool === "circle" ? (lat, lng) => setCentre({ lat, lng }) : undefined}
            circle={ed.tool === "circle" ? { ...centre, radiusKm: radiusN || 0 } : null}
            ghost={{ exclude: NO_EXCLUDE }}
            onGhostState={setGhostState}
            className="rounded-none"
          />
        </div>
      </Card>

      <div className="grid content-start gap-4">
        <Card>
          <CardHeader>
            <CardTitle className="font-semibold">Service area</CardTitle>
            <CardDescription>H3 resolution {city.h3Resolution}</CardDescription>
          </CardHeader>
          <CardContent className="grid gap-3">
            <dl className="grid grid-cols-2 gap-3">
              <div>
                <dt className="text-xs text-muted-foreground">Hexagons</dt>
                <dd className="font-heading text-xl font-semibold tabular-nums">{formatCount(ed.cells.length)}</dd>
              </div>
              <div>
                <dt className="text-xs text-muted-foreground">Area</dt>
                <dd className="font-heading text-xl font-semibold tabular-nums">
                  {formatCount(Math.round(cellsToKm2(ed.cells.length, city.h3Resolution)))} km²
                </dd>
              </div>
            </dl>
            {isDirty && (
              <p className="rounded-md bg-warning-tint px-2.5 py-1.5 text-xs text-warning-text">
                Unsaved: {ed.cells.length - baseline.length >= 0 ? "+" : ""}
                {formatCount(ed.cells.length - baseline.length)} cells vs saved
              </p>
            )}
            <Button
              disabled={!isDirty || isPending}
              onClick={() =>
                startTransition(async () => {
                  const res = await saveServiceCells(city.id, [...ed.cells]);
                  if (res.ok) {
                    setBaseline([...ed.cells]);
                    toast.success(res.message);
                  } else toast.error(res.error);
                })
              }
            >
              {isPending ? <Loader2Icon className="animate-spin" /> : <SaveIcon />} Save service area
            </Button>
            <div className="flex gap-2">
              <Button variant="outline" size="sm" className="flex-1" disabled={!isDirty} onClick={() => ed.commit(baseline)}>
                Discard changes
              </Button>
              <Button
                variant="outline"
                size="sm"
                className="flex-1 text-error"
                disabled={ed.cells.length === 0}
                onClick={() => ed.commit([])}
              >
                <Trash2Icon /> Clear
              </Button>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="font-semibold">Fill circle</CardTitle>
            <CardDescription>
              {ed.tool === "circle" ? "Click the map to move the centre." : "Choose the Circle tool to pick a centre on the map."}
            </CardDescription>
          </CardHeader>
          <CardContent className="grid gap-3">
            <p className="font-mono text-xs text-navy-700">
              {centre.lat.toFixed(5)}, {centre.lng.toFixed(5)}
            </p>
            <div className="grid gap-1.5">
              <Label htmlFor="circle-radius">Radius (km)</Label>
              <Input id="circle-radius" inputMode="decimal" value={radius} onChange={(e) => setRadius(e.target.value)} />
            </div>
            <div className="flex gap-2">
              <Button variant="outline" size="sm" className="flex-1" onClick={() => fillCircle("add")}>
                Add circle
              </Button>
              <Button variant="outline" size="sm" className="flex-1" onClick={() => fillCircle("remove")}>
                Remove circle
              </Button>
            </div>
          </CardContent>
        </Card>
        <p className="px-1 text-xs text-muted-foreground">Shortcuts: Ctrl+Z undo, Ctrl+Shift+Z redo.</p>
      </div>
    </div>
  );
}
