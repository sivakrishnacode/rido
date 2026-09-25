"use client";

import { RouteError } from "./route-error";

/** Default export shape for error.tsx files. */
export default function ErrorBoundary(props: { error: Error & { digest?: string }; retry: () => void }) {
  return <RouteError {...props} />;
}
