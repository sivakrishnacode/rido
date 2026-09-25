"use client";

import { APIProvider, Map, useApiLoadingStatus, type MapProps } from "@vis.gl/react-google-maps";
import { MapPinOffIcon } from "lucide-react";
import { useEffect, useState } from "react";

import { cn } from "@/lib/utils";

import { GOOGLE_MAPS_KEY, RIDO_MAP_STYLES } from "./style";

export type MapType = "roadmap" | "hybrid";

declare global {
  interface Window {
    gm_authFailure?: () => void;
  }
}

/** Google calls window.gm_authFailure for bad keys and for keys whose Maps JavaScript API isn't enabled. */
function useAuthFailure(): boolean {
  const [isFailed, setFailed] = useState(false);
  useEffect(() => {
    const previous = window.gm_authFailure;
    window.gm_authFailure = () => {
      setFailed(true);
      previous?.();
    };
    return () => {
      window.gm_authFailure = previous;
    };
  }, []);
  return isFailed;
}

function StatusOverlay() {
  const status = useApiLoadingStatus();
  const isAuthFailed = useAuthFailure();
  let message: { title: string; body: string } | null = null;
  if (!GOOGLE_MAPS_KEY) {
    message = {
      title: "Google Maps key missing",
      body: "Set NEXT_PUBLIC_GOOGLE_MAPS_BROWSER_KEY (apps/admin/.env.local, or GOOGLE_MAPS_BROWSER_KEY for Docker) and rebuild.",
    };
  } else if (isAuthFailed || status === "AUTH_FAILURE") {
    message = {
      title: "Google Maps refused this key",
      body: "Enable the Maps JavaScript API for this key in Google Cloud → APIs & Services → Library (and check the key's referrer restrictions).",
    };
  } else if (status === "FAILED") {
    message = { title: "Couldn't load Google Maps", body: "Check the internet connection, then reload the page." };
  }
  if (!message) return null;
  return (
    <div role="alert" className="absolute inset-0 z-20 flex items-center justify-center bg-muted/95 p-6 text-center">
      <div className="max-w-sm space-y-2">
        <span className="mx-auto flex size-10 items-center justify-center rounded-full bg-error-tint text-error">
          <MapPinOffIcon className="size-5" aria-hidden />
        </span>
        <p className="font-heading font-semibold text-navy-900">{message.title}</p>
        <p className="text-sm text-navy-700">{message.body}</p>
      </div>
    </div>
  );
}

/**
 * Google map with Rido styling. Children run inside the map context (useMap); [overlay] is absolutely positioned
 * UI on top of the map (search box, toolbars).
 */
export function RidoMap({
  center,
  zoom = 12,
  mapType = "roadmap",
  className,
  overlay,
  children,
  options,
}: {
  center: google.maps.LatLngLiteral;
  zoom?: number;
  mapType?: MapType;
  className?: string;
  overlay?: React.ReactNode;
  children?: React.ReactNode;
  options?: Partial<MapProps>;
}) {
  return (
    <div className={cn("relative overflow-hidden rounded-xl bg-[#EEF0F3]", className)}>
      <APIProvider apiKey={GOOGLE_MAPS_KEY} language="en" region="IN">
        {GOOGLE_MAPS_KEY && (
          <Map
            className="h-full w-full"
            defaultCenter={center}
            defaultZoom={zoom}
            mapTypeId={mapType}
            styles={RIDO_MAP_STYLES}
            gestureHandling="greedy"
            clickableIcons={false}
            disableDefaultUI
            zoomControl
            {...options}
          >
            {children}
          </Map>
        )}
        {overlay}
        <StatusOverlay />
      </APIProvider>
    </div>
  );
}
