"use client";

import { useMap } from "@vis.gl/react-google-maps";
import { ArrowRightIcon, GaugeIcon, Loader2Icon, RefreshCwIcon } from "lucide-react";
import { useEffect, useMemo, useState, useTransition } from "react";
import { Bar, BarChart, CartesianGrid, XAxis, YAxis } from "recharts";
import { toast } from "sonner";

import { EmptyState } from "@/components/common/page";
import { HexLayer } from "@/components/map/google/hex-layer";
import { RidoMap } from "@/components/map/google/rido-map";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { ChartContainer, ChartTooltip, ChartTooltipContent, type ChartConfig } from "@/components/ui/chart";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { formatCount, formatDateTime } from "@/lib/format";
import { cellCentre, cellsBounds } from "@/lib/hex";
import { hourLabel, speedByHour } from "@/lib/speeds";
import type { HexStatRow, HexStats } from "@/lib/types";
import { cn } from "@/lib/utils";

import { rebuildHexStats } from "../actions";

const chartConfig = { speed: { label: "Avg km/h", color: "var(--chart-1)" } } satisfies ChartConfig;

function FitPair({ row }: { row: HexStatRow | null }) {
  const map = useMap();
  useEffect(() => {
    if (!map || !row) return;
    const b = cellsBounds([row.fromCell, row.toCell]);
    if (b) map.fitBounds({ south: b.south - 0.02, north: b.north + 0.02, west: b.west - 0.02, east: b.east + 0.02 }, 40);
    const line = new google.maps.Polyline({
      map,
      path: [cellCentre(row.fromCell), cellCentre(row.toCell)],
      clickable: false,
      strokeColor: "#1E293B",
      strokeWeight: 2,
      icons: [{ icon: { path: google.maps.SymbolPath.FORWARD_CLOSED_ARROW, scale: 3, strokeColor: "#1E293B" }, offset: "100%" }],
      zIndex: 10,
    });
    return () => line.setMap(null);
  }, [map, row]);
  return null;
}

export function SpeedsView({ stats, names, minTrips }: { stats: HexStats; names: Record<string, string | null>; minTrips: number }) {
  const [selected, setSelected] = useState<HexStatRow | null>(stats.top[0] ?? null);
  const [isPending, startTransition] = useTransition();
  const byHour = useMemo(() => speedByHour(stats.top), [stats.top]);
  const name = (c: string) => names[c] ?? `${c.slice(0, 9)}…`;

  return (
    <div className="grid gap-4">
      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardHeader>
            <CardDescription>Learned hex-pair / hour rows</CardDescription>
            <CardTitle className="font-heading text-3xl font-semibold tabular-nums">{formatCount(stats.rows)}</CardTitle>
          </CardHeader>
          <CardContent className="text-xs text-muted-foreground">
            Last rebuilt {stats.lastRun ? formatDateTime(stats.lastRun) : "never"}. Learned ETAs are used for pairs with ≥{" "}
            <b className="text-navy-900">{minTrips || "–"}</b> trips {minTrips ? "" : "(off: set “Learned ETA after” in Settings)"}.
            <Button
              className="mt-3 w-full"
              disabled={isPending}
              onClick={() =>
                startTransition(async () => {
                  const res = await rebuildHexStats();
                  if (res.ok) toast.success(res.message);
                  else toast.error(res.error);
                })
              }
            >
              {isPending ? <Loader2Icon className="animate-spin" /> : <RefreshCwIcon />} Rebuild now
            </Button>
          </CardContent>
        </Card>
        <Card className="md:col-span-2">
          <CardHeader>
            <CardTitle className="font-semibold">Average speed by hour</CardTitle>
            <CardDescription>Trip-weighted over the top {stats.top.length} pairs (IST)</CardDescription>
          </CardHeader>
          <CardContent>
            {byHour.length === 0 ? (
              <p className="py-6 text-center text-sm text-muted-foreground">No data yet. Rebuild after some trips complete.</p>
            ) : (
              <ChartContainer config={chartConfig} className="aspect-auto h-44 w-full">
                <BarChart data={byHour} margin={{ left: -16, right: 8, top: 8 }}>
                  <CartesianGrid vertical={false} />
                  <XAxis dataKey="hour" tickLine={false} axisLine={false} fontSize={10} />
                  <YAxis tickLine={false} axisLine={false} width={40} unit=" " />
                  <ChartTooltip cursor={false} content={<ChartTooltipContent hideIndicator />} />
                  <Bar dataKey="speed" fill="var(--color-speed)" radius={4} maxBarSize={36} />
                </BarChart>
              </ChartContainer>
            )}
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 xl:grid-cols-[1fr_420px]">
        <Card className="gap-0 py-0">
          {stats.top.length === 0 ? (
            <EmptyState icon={GaugeIcon} title="No learned speeds" description="Press Rebuild now once trips have completed." />
          ) : (
            <Table>
              <TableHeader>
                <TableRow className="bg-muted/40 hover:bg-muted/40">
                  <TableHead className="pl-4">From → to</TableHead>
                  <TableHead>Hour</TableHead>
                  <TableHead className="text-right">Trips</TableHead>
                  <TableHead className="text-right">Avg km/h</TableHead>
                  <TableHead className="pr-4 text-right">Avg min</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {stats.top.map((r) => {
                  const isSel = selected === r;
                  return (
                    <TableRow
                      key={`${r.fromCell}-${r.toCell}-${r.hour}`}
                      className={cn("cursor-pointer", isSel && "bg-coral-50/70 hover:bg-coral-50")}
                      onClick={() => setSelected(r)}
                      aria-selected={isSel}
                    >
                      <TableCell className="pl-4">
                        <span className="flex flex-wrap items-center gap-1.5 text-sm text-navy-900">
                          {name(r.fromCell)} <ArrowRightIcon className="size-3.5 text-muted-foreground" /> {name(r.toCell)}
                          {r.fromCell === r.toCell && <Badge variant="outline">same hex</Badge>}
                        </span>
                        <span className="font-mono text-[10px] text-muted-foreground">
                          {r.fromCell} → {r.toCell}
                        </span>
                      </TableCell>
                      <TableCell className="tabular-nums">{hourLabel(r.hour)}</TableCell>
                      <TableCell className="text-right tabular-nums">
                        {r.trips}
                        {minTrips > 0 && r.trips >= minTrips && <span className="ml-1 text-[10px] text-success-text">used</span>}
                      </TableCell>
                      <TableCell className="text-right font-medium tabular-nums">{r.avgSpeedKmh.toFixed(1)}</TableCell>
                      <TableCell className="pr-4 text-right tabular-nums">{r.avgDurationMin.toFixed(1)}</TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}
        </Card>

        <div className="grid content-start gap-2">
          <RidoMap
            center={selected ? cellCentre(selected.fromCell) : { lat: 11.0168, lng: 76.9658 }}
            zoom={12}
            className="h-[420px] border xl:sticky xl:top-20"
          >
            {selected && (
              <>
                <HexLayer cells={[selected.fromCell]} style={{ color: "#D84315", fillColor: "#F4511E", fillOpacity: 0.3, weight: 2 }} zIndex={2} />
                <HexLayer
                  cells={selected.toCell === selected.fromCell ? [] : [selected.toCell]}
                  style={{ color: "#1E293B", fillColor: "#334155", fillOpacity: 0.25, weight: 2 }}
                  zIndex={2}
                />
                <FitPair row={selected} />
              </>
            )}
          </RidoMap>
          {selected && (
            <p className="px-1 text-xs text-muted-foreground">
              <span className="font-medium text-coral-700">■ from</span> {name(selected.fromCell)} ·{" "}
              <span className="font-medium text-navy-900">■ to</span> {name(selected.toCell)} · {hourLabel(selected.hour)} ·{" "}
              {selected.avgSpeedKmh.toFixed(1)} km/h over {selected.trips} trips
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
