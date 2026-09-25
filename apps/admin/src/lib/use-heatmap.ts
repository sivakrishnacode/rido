"use client";

import { useEffect, useState } from "react";

import { heatQuery } from "./heat";
import type { Heatmap, HeatmapQuery } from "./types";

/** Fetches /api/heatmap for [query], debounced 300 ms; keeps the last good data while reloading. */
export function useHeatmap(query: HeatmapQuery | null, initial: Heatmap | null = null) {
  const [data, setData] = useState<Heatmap | null>(initial);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setLoading] = useState(false);
  const key = query ? heatQuery(query) : null;

  useEffect(() => {
    if (key === null) return;
    let isCancelled = false;
    const timer = setTimeout(async () => {
      setLoading(true);
      try {
        const res = await fetch(`/api/heatmap?${key}`, { cache: "no-store" });
        const body = (await res.json().catch(() => null)) as (Heatmap & { message?: string }) | null;
        if (res.status === 401) {
          window.location.replace("/auth/signout?expired=1");
          return;
        }
        if (!res.ok || !body) throw new Error(body?.message ? String(body.message) : "Heatmap failed");
        if (!isCancelled) {
          setData(body);
          setError(null);
        }
      } catch (e) {
        if (!isCancelled) setError(e instanceof Error ? e.message : "Heatmap failed");
      } finally {
        if (!isCancelled) setLoading(false);
      }
    }, 300);
    return () => {
      isCancelled = true;
      clearTimeout(timer);
    };
  }, [key]);

  return { data, error, isLoading };
}
