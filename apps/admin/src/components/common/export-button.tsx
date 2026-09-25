import { DownloadIcon } from "lucide-react";

import { Button } from "@/components/ui/button";

/** Downloads a CSV through the /export/[entity] route handler (the API needs the admin cookie). */
export function ExportButton({ entity }: { entity: "trips" | "drivers" | "payments" }) {
  return (
    <Button asChild variant="outline">
      {/* A plain <a> so the browser treats the response as a file download. */}
      <a href={`/export/${entity}`} download={`rido-${entity}.csv`}>
        <DownloadIcon /> Export CSV
      </a>
    </Button>
  );
}
