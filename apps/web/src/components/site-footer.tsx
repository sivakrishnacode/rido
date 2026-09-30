import Link from "next/link";

import { site } from "@/lib/site";

import { Wordmark } from "./logo";

const links = [
  { href: "/privacy/", label: "Privacy policy" },
  { href: "/terms/", label: "Terms of service" },
  { href: "/delete-account/", label: "Delete your account" },
];

export function SiteFooter() {
  return (
    <footer className="border-t border-divider bg-page">
      <div className="mx-auto flex max-w-6xl flex-col gap-8 px-4 py-10 sm:px-6 md:flex-row md:justify-between">
        <div className="max-w-xs space-y-3">
          <Wordmark className="text-[26px]" />
          <p className="text-sm text-navy-500">
            Rides and parcels for {site.city}. 0% commission, no subscription.
          </p>
        </div>
        <div className="flex flex-col gap-8 text-sm sm:flex-row sm:gap-16">
          <ul className="space-y-2">
            {links.map((l) => (
              <li key={l.href}>
                <Link href={l.href} className="text-navy-700 hover:text-coral-600">
                  {l.label}
                </Link>
              </li>
            ))}
          </ul>
          <ul className="space-y-2">
            <li>
              <a href={`mailto:${site.email}`} className="text-navy-700 hover:text-coral-600">
                {site.email}
              </a>
            </li>
            <li>
              <a href={site.github} className="text-navy-700 hover:text-coral-600">
                Source code on GitHub
              </a>
            </li>
            <li className="text-navy-500">Open source, AGPL-3.0</li>
          </ul>
        </div>
      </div>
    </footer>
  );
}
