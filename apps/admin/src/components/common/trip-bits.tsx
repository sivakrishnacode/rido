import { cn } from "@/lib/utils";

/** Pickup → drop, two lines with a small coral/navy route marker. */
export function TripRouteCell({ pickup, drop, className }: { pickup: string; drop: string; className?: string }) {
  return (
    <span className={cn("flex min-w-44 max-w-72 gap-2", className)}>
      <span aria-hidden className="mt-1.5 flex flex-col items-center">
        <span className="size-2 rounded-full bg-success" />
        <span className="my-0.5 h-3 w-px bg-navy-300" />
        <span className="size-2 rounded-[2px] bg-coral-600" />
      </span>
      <span className="min-w-0 text-sm">
        <span className="block truncate text-navy-900" title={pickup}>
          {pickup}
        </span>
        <span className="block truncate text-navy-700" title={drop}>
          {drop}
        </span>
      </span>
    </span>
  );
}
