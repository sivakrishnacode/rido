import { cn } from "@/lib/utils";

import { LOGO_PATHS } from "./logo-paths";

/**
 * The Tamil Taxi logo: "Tamil Taxi" in Manrope ExtraBold whose x is a flyover road with lane dashes.
 * Drawn from outline paths, so it never depends on a font. Sized by font size (`text-3xl` etc.): the letters are set
 * at 1em. `stacked` gives the two-line primary logo, otherwise one line. The road is always coral; the letters are
 * navy, or white on dark backgrounds.
 */
export function Wordmark({
  className,
  tone = "navy",
  stacked = false,
}: {
  className?: string;
  tone?: "navy" | "white";
  stacked?: boolean;
}) {
  const logo = stacked ? LOGO_PATHS.stacked : LOGO_PATHS.oneLine;
  return (
    <span
      role="img"
      aria-label="Tamil Taxi"
      className={cn(
        "inline-block leading-none select-none",
        tone === "white" ? "text-white" : "text-navy-900",
        className,
      )}
    >
      <svg
        viewBox={`0 0 ${logo.width} ${logo.height}`}
        style={{ height: `${logo.height / 100}em`, width: `${logo.width / 100}em` }}
        className="block"
        aria-hidden
      >
        <path d={logo.fg} fill="currentColor" />
        <path d={logo.road} fill="#F4511E" />
      </svg>
    </span>
  );
}
