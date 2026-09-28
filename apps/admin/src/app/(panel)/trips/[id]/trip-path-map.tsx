"use client";

import { useMap } from "@vis.gl/react-google-maps";
import { useEffect, useMemo } from "react";

import { RidoMap } from "@/components/map/google/rido-map";
import { decodePolyline } from "@/lib/polyline";

type Point = { lat: number; lng: number };

function PathLayer({ path, route, ends }: { path: Point[]; route: Point[]; ends: [number, number, number, number] }) {
  const map = useMap();
  const [pickupLat, pickupLng, dropLat, dropLng] = ends;
  useEffect(() => {
    if (!map) return;
    const pickup = { lat: pickupLat, lng: pickupLng };
    const drop = { lat: dropLat, lng: dropLng };
    const bounds = new google.maps.LatLngBounds();
    [...path, ...route, pickup, drop].forEach((p) => bounds.extend(p));
    map.fitBounds(bounds, 32);
    // The quoted route: dashed navy, under the recorded path.
    const quoted = new google.maps.Polyline({
      map,
      path: route,
      strokeOpacity: 0,
      clickable: false,
      zIndex: 1,
      icons: [{ icon: { path: "M 0,-1 0,1", strokeOpacity: 0.7, strokeColor: "#1A2340", scale: 3 }, offset: "0", repeat: "14px" }],
    });
    const line = new google.maps.Polyline({ map, path, strokeColor: "#D84315", strokeOpacity: 0.9, strokeWeight: 4, clickable: false, zIndex: 2 });
    const stops = new google.maps.Data({ map });
    stops.setStyle((f) => ({
      clickable: false,
      icon: {
        path: google.maps.SymbolPath.CIRCLE,
        scale: 6,
        fillColor: f.getProperty("kind") === "pickup" ? "#2E7D32" : "#1A2340",
        fillOpacity: 1,
        strokeColor: "#FFFFFF",
        strokeWeight: 2,
      },
    }));
    stops.add({ geometry: pickup, properties: { kind: "pickup" } });
    stops.add({ geometry: drop, properties: { kind: "drop" } });
    return () => {
      quoted.setMap(null);
      line.setMap(null);
      stops.setMap(null);
    };
  }, [map, path, route, pickupLat, pickupLng, dropLat, dropLng]);
  return null;
}

/** The recorded ride path (orange) over the quoted route (dashed navy), with the pickup (green) and drop (navy). */
export function TripPathMap({ polyline, route, pickup, drop }: { polyline: string | null; route?: string | null; pickup: Point; drop: Point }) {
  const path = useMemo(() => (polyline ? decodePolyline(polyline) : []), [polyline]);
  const quoted = useMemo(() => (route ? decodePolyline(route) : []), [route]);
  return (
    <RidoMap center={pickup} zoom={13} className="h-72">
      <PathLayer path={path} route={quoted} ends={[pickup.lat, pickup.lng, drop.lat, drop.lng]} />
    </RidoMap>
  );
}
