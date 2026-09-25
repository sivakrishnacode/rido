import { cn } from "@/lib/utils";

/** "rido" wordmark: navy letters, the dot of the i in coral. */
export function Wordmark({ className, tone = "navy" }: { className?: string; tone?: "navy" | "white" }) {
  return (
    <span
      aria-label="rido"
      className={cn(
        "inline-flex items-baseline font-heading font-bold leading-none tracking-tight select-none",
        tone === "white" ? "text-white" : "text-navy-900",
        className,
      )}
    >
      <span aria-hidden>r</span>
      <span aria-hidden className="relative inline-block">
        ı
        <span
          className={cn(
            "absolute left-1/2 top-[0.02em] size-[0.2em] -translate-x-1/2 rounded-full",
            tone === "white" ? "bg-white" : "bg-coral-600",
          )}
        />
      </span>
      <span aria-hidden>do</span>
    </span>
  );
}
