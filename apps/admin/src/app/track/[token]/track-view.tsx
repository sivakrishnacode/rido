"use client";

import { useMap } from "@vis.gl/react-google-maps";
import { ClockIcon, MapPinOffIcon, NavigationIcon } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";

import { PlateBadge } from "@/components/common/status";
import { TtMap } from "@/components/map/google/tamiltaxi-map";
import { Card, CardContent } from "@/components/ui/card";
import { TRACK_POLL_MS, trackModel, type ShareResult, type TrackModel } from "@/lib/track";
import { cn } from "@/lib/utils";

type Point = { lat: number; lng: number };

/** Pickup (green), drop (navy) and the vehicle (coral); fits the map when the leg changes. */
function TripLayer({ model }: { model: TrackModel }) {
  const map = useMap();
  const data = useRef<google.maps.Data | null>(null);
  const fittedFor = useRef<string | null>(null);
  const { pickup, drop, vehicle, fit } = model;

  useEffect(() => {
    if (!map) return;
    const layer = new google.maps.Data({ map });
    layer.setStyle((f) => {
      const kind = f.getProperty("kind");
      return {
        clickable: false,
        zIndex: kind === "vehicle" ? 3 : 1,
        icon: {
          path: google.maps.SymbolPath.CIRCLE,
          scale: kind === "vehicle" ? 9 : 6,
          fillColor: kind === "vehicle" ? "#F4511E" : kind === "pickup" ? "#2E7D32" : "#1A2340",
          fillOpacity: 1,
          strokeColor: "#FFFFFF",
          strokeWeight: kind === "vehicle" ? 3 : 2,
        },
      };
    });
    data.current = layer;
    return () => {
      layer.setMap(null);
      data.current = null;
    };
  }, [map]);

  useEffect(() => {
    const layer = data.current;
    if (!map || !layer) return;
    layer.forEach((f) => layer.remove(f));
    layer.add({ geometry: pickup, properties: { kind: "pickup" } });
    layer.add({ geometry: drop, properties: { kind: "drop" } });
    if (vehicle) layer.add({ geometry: vehicle, properties: { kind: "vehicle" } });
    // Fit once per leg (to the pickup, to the drop, ended), not on every fix: the viewer may have zoomed.
    const leg = `${vehicle ? "live" : "static"}:${fit.at(-1)?.lat},${fit.at(-1)?.lng}`;
    if (fittedFor.current !== leg) {
      fittedFor.current = leg;
      const bounds = new google.maps.LatLngBounds();
      fit.forEach((p: Point) => bounds.extend(p));
      map.fitBounds(bounds, 48);
    }
  }, [map, pickup, drop, vehicle, fit]);

  return null;
}

function Message({ title, body }: { title: string; body: string }) {
  return (
    <Card>
      <CardContent className="flex flex-col items-center gap-2 py-10 text-center">
        <span className="flex size-10 items-center justify-center rounded-full bg-muted text-navy-700">
          <MapPinOffIcon className="size-5" aria-hidden />
        </span>
        <p className="font-heading font-semibold text-navy-900">{title}</p>
        <p className="text-sm text-navy-700">{body}</p>
      </CardContent>
    </Card>
  );
}

/** The live trip: polls every few seconds while the trip runs; stops once it has ended or the link expired. */
export function TrackView({ token, initial }: { token: string; initial: ShareResult }) {
  const [result, setResult] = useState<ShareResult>(initial);
  const [now, setNow] = useState(() => Date.now());
  const last = useRef<ShareResult>(initial);

  const isPolling = result.kind === "error" || (result.kind === "ok" && result.view.isLive);
  useEffect(() => {
    if (!isPolling) return;
    let isCancelled = false;
    const tick = async () => {
      try {
        const res = await fetch(`/api/track/${encodeURIComponent(token)}`, { cache: "no-store" });
        const next = (await res.json()) as ShareResult;
        if (isCancelled) return;
        // Keep showing the last good view through a transient error.
        if (next.kind === "error" && last.current.kind === "ok") return;
        last.current = next;
        setResult(next);
      } catch {
        // Offline for a moment: try again on the next tick.
      } finally {
        if (!isCancelled) setNow(Date.now());
      }
    };
    const id = setInterval(tick, TRACK_POLL_MS);
    return () => {
      isCancelled = true;
      clearInterval(id);
    };
  }, [token, isPolling]);

  const view = result.kind === "ok" ? result.view : null;
  const model = useMemo(() => (view ? trackModel(view, now) : null), [view, now]);

  if (result.kind === "ended") return <Message title="This trip has ended" body="The live location is no longer shared." />;
  if (result.kind === "not-found") return <Message title="Link not found" body="Check the link you were sent, or ask for a new one." />;
  if (!model) return <Message title="Loading the trip…" body={result.kind === "error" ? result.message : ""} />;

  return (
    <>
      <TtMap center={model.vehicle ?? model.pickup} zoom={14} className="h-[55dvh] min-h-72">
        <TripLayer model={model} />
      </TtMap>
      <Card>
        <CardContent className="space-y-3 py-4">
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0">
              <p className="font-heading text-lg leading-snug font-semibold text-navy-900">{model.title}</p>
              <p className="flex items-center gap-1.5 text-sm text-navy-700">
                {model.isLive && <span aria-hidden className="size-2 animate-pulse rounded-full bg-coral-600" />}
                {model.status}
              </p>
            </div>
            {model.plate && <PlateBadge plate={model.plate} />}
          </div>
          {model.driverLine && <p className="text-sm text-navy-900">{model.driverLine}</p>}
          {model.etaLine && (
            <p className="flex items-center gap-2 text-sm text-navy-900">
              <ClockIcon className="size-4 text-coral-600" aria-hidden />
              {model.etaLine}
            </p>
          )}
          <div className="grid gap-1 text-sm">
            <p className="flex items-center gap-2">
              <span aria-hidden className="size-2.5 rounded-full bg-[#2E7D32]" />
              <span className="text-muted-foreground">From</span> <span className="truncate">{model.pickup.name}</span>
            </p>
            <p className="flex items-center gap-2">
              <span aria-hidden className="size-2.5 rounded-full bg-navy-900" />
              <span className="text-muted-foreground">To</span> <span className="truncate">{model.drop.name}</span>
            </p>
          </div>
          {model.freshness && (
            <p className={cn("flex items-center gap-1.5 text-xs", model.isStale ? "text-error" : "text-muted-foreground")}>
              <NavigationIcon className="size-3.5" aria-hidden />
              {model.freshness}
            </p>
          )}
        </CardContent>
      </Card>
    </>
  );
}
