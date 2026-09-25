"use client";

import { TriangleAlertIcon } from "lucide-react";
import { useEffect } from "react";

import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";

/** Shared body of every error.tsx (Next 16 passes `retry`, which re-renders the segment). */
export function RouteError({
  error,
  retry,
  title = "Something went wrong",
}: {
  error: Error & { digest?: string };
  retry: () => void;
  title?: string;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  // In production Next.js hides server error messages; show them in development only.
  const detail = process.env.NODE_ENV === "development" ? error.message : undefined;

  return (
    <Card className="mx-auto mt-6 max-w-lg items-center gap-3 px-6 py-10 text-center">
      <span className="flex size-11 items-center justify-center rounded-full bg-error-tint text-error">
        <TriangleAlertIcon className="size-5" aria-hidden />
      </span>
      <h2 className="font-heading text-lg font-semibold text-navy-900">{title}</h2>
      <p className="text-sm text-muted-foreground">
        We couldn&apos;t load this page from the Rido API. Check that the API is running, then try again.
      </p>
      {detail && <p className="rounded-md bg-muted px-3 py-2 font-mono text-xs text-navy-700">{detail}</p>}
      {error.digest && <p className="text-xs text-muted-foreground">Reference: {error.digest}</p>}
      <Button onClick={() => retry()} className="mt-2">
        Try again
      </Button>
    </Card>
  );
}
