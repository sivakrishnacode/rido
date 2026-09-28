"use client";

import { useMap } from "@vis.gl/react-google-maps";
import { useEffect, useMemo } from "react";

import { RidoMap } from "@/components/map/google/rido-map";
import { decodePolyline } from "@/lib/polyline";

type Point = { lat: number; lng: number };

function PathLayer({ path, ends }: { path: Point[]; ends: [number, number, number, number] }) {
  const map = useMap();
  const [pickupLat, pickupLng, dropLat, dropLng] = ends;
  useEffect(() => {
    if (!map) return;
    const pickup = { lat: pickupLat, lng: pickupLng };
    const drop = { lat: dropLat, lng: dropLng };
    const bounds = new google.maps.LatLngBounds();
    [...path, pickup, drop].forEach((p) => bounds.extend(p));
    map.fitBounds(bounds, 32);
    const line = new google.maps.Polyline({ map, path, strokeColor: "#D84315", strokeOpacity: 0.9, strokeWeight: 4, clickable: false });
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
      line.setMap(null);
      stops.setMap(null);
    };
  }, [map, path, pickupLat, pickupLng, dropLat, dropLng]);
  return null;
}

/** The recorded ride path (orange) with the booked pickup (green) and drop (navy). */
export function TripPathMap({ polyline, pickup, drop }: { polyline: string; pickup: Point; drop: Point }) {
  const path = useMemo(() => decodePolyline(polyline), [polyline]);
  return (
    <RidoMap center={pickup} zoom={13} className="h-72">
      <PathLayer path={path} ends={[pickup.lat, pickup.lng, drop.lat, drop.lng]} />
    </RidoMap>
  );
}
