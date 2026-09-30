import Link from "next/link";

import { Wordmark } from "./logo";

const nav = [
  { href: "/#ride", label: "Ride" },
  { href: "/#drive", label: "Drive" },
  { href: "/#free", label: "Why it's free" },
];

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-40 border-b border-divider bg-white/85 backdrop-blur">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between gap-6 px-4 sm:px-6">
        <Link href="/" aria-label="Tamil Taxi home">
          <Wordmark className="text-[26px]" />
        </Link>
        <nav aria-label="Main" className="flex items-center gap-1 sm:gap-2">
          {nav.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="hidden rounded-lg px-3 py-2 text-sm font-medium text-navy-700 hover:bg-page hover:text-navy-900 md:block"
            >
              {item.label}
            </Link>
          ))}
          <Link
            href="/#download"
            className="ml-2 rounded-full bg-coral-600 px-4 py-2 text-sm font-semibold text-white hover:bg-coral-700"
          >
            Get the app
          </Link>
        </nav>
      </div>
    </header>
  );
}
