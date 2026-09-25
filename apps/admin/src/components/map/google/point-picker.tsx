"use client";

import { useMap } from "@vis.gl/react-google-maps";
import { useEffect, useRef } from "react";

import { RidoMap } from "./rido-map";

function Picker({ lat, lng, onPick }: { lat: number; lng: number; onPick: (lat: number, lng: number) => void }) {
  const map = useMap();
  const pick = useRef(onPick);
  useEffect(() => {
    pick.current = onPick;
  });
  useEffect(() => {
    if (!map) return;
    map.setOptions({ draggableCursor: "crosshair" });
    const l = map.addListener("click", (e: google.maps.MapMouseEvent) => {
      if (e.latLng) pick.current(Number(e.latLng.lat().toFixed(6)), Number(e.latLng.lng().toFixed(6)));
    });
    return () => l?.remove();
  }, [map]);
  const isSet = Number.isFinite(lat) && Number.isFinite(lng);
  useEffect(() => {
    if (!map || !isSet) return;
    map.panTo({ lat, lng });
    const layer = new google.maps.Data({ map });
    layer.setStyle({
      clickable: false,
      icon: { path: google.maps.SymbolPath.CIRCLE, scale: 7, fillColor: "#D84315", fillOpacity: 1, strokeColor: "#FFFFFF", strokeWeight: 2 },
    });
    layer.add({ geometry: { lat, lng } });
    return () => layer.setMap(null);
  }, [map, lat, lng, isSet]);
  return null;
}

/** Small map: click to set a point (city centre). */
export function PointPicker({ lat, lng, onPick, className }: { lat: number; lng: number; onPick: (lat: number, lng: number) => void; className?: string }) {
  const isSet = Number.isFinite(lat) && Number.isFinite(lng);
  return (
    <RidoMap center={isSet ? { lat, lng } : { lat: 11.0168, lng: 76.9658 }} zoom={isSet ? 11 : 7} className={className ?? "h-full"}>
      <Picker lat={lat} lng={lng} onPick={onPick} />
    </RidoMap>
  );
}
