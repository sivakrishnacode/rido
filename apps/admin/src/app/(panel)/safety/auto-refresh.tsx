"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";

/** Re-renders the page's server data every [ms] (no admin realtime channel: the SOS page polls). */
export function AutoRefresh({ ms }: { ms: number }) {
  const router = useRouter();
  useEffect(() => {
    const id = setInterval(() => {
      if (document.visibilityState === "visible") router.refresh();
    }, ms);
    return () => clearInterval(id);
  }, [router, ms]);
  return null;
}
