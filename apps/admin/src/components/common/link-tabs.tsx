import Link from "next/link";

import { cn } from "@/lib/utils";

/** Tabs that are plain links (the selected tab lives in the URL, so it survives reloads and sharing). */
export function LinkTabs({
  tabs,
  active,
  className,
}: {
  tabs: readonly { href: string; label: string; value: string; count?: React.ReactNode }[];
  active: string;
  className?: string;
}) {
  return (
    <nav
      aria-label="Filter"
      className={cn("mb-4 inline-flex max-w-full gap-1 overflow-x-auto rounded-lg bg-muted p-1 text-sm", className)}
    >
      {tabs.map((t) => {
        const isActive = t.value === active;
        return (
          <Link
            key={t.value}
            href={t.href}
            aria-current={isActive ? "page" : undefined}
            className={cn(
              "inline-flex items-center gap-1.5 rounded-md px-3 py-1.5 font-medium whitespace-nowrap text-navy-700 transition-colors hover:text-navy-900",
              isActive && "bg-card text-navy-900 shadow-sm",
            )}
          >
            {t.label}
            {t.count}
          </Link>
        );
      })}
    </nav>
  );
}
