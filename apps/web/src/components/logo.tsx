import { LOGO_PATHS } from "./logo-paths";

/**
 * The Tamil Taxi logo, as in the apps (TtWordmark) and the admin panel (Wordmark): "Tamil Taxi" whose x is a flyover
 * road. Drawn from outline paths (logo-paths.ts, a copy of apps/admin/src/components/common/logo-paths.ts), so it
 * never depends on a font. Sized by font size: the letters are set at 1em.
 */
export function Wordmark({ className = "" }: { className?: string }) {
  const logo = LOGO_PATHS.oneLine;
  return (
    <span role="img" aria-label="Tamil Taxi" className={`inline-block leading-none text-navy-900 select-none ${className}`}>
      <svg
        viewBox={`0 0 ${logo.width} ${logo.height}`}
        style={{ height: `${logo.height / 100}em`, width: `${logo.width / 100}em` }}
        className="block"
        aria-hidden="true"
      >
        <path d={logo.fg} fill="currentColor" />
        <path d={logo.road} fill="#F4511E" />
      </svg>
    </span>
  );
}
