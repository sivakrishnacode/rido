"use client";

import { MenuIcon, SearchIcon } from "lucide-react";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";

import { Wordmark } from "@/components/common/wordmark";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { cn } from "@/lib/utils";

import { DEFAULT_SEARCH, NAV_GROUPS, activeNav } from "./nav";

function SidebarNav({
  pathname,
  badges,
  onNavigate,
}: {
  pathname: string;
  badges?: Record<string, React.ReactNode>;
  onNavigate?: () => void;
}) {
  const current = activeNav(pathname);
  return (
    <nav aria-label="Main" className="flex flex-col gap-5">
      {NAV_GROUPS.map((group) => (
        <div key={group.label} className="flex flex-col gap-0.5">
          <p className="px-3 pb-1 text-[11px] font-semibold tracking-wider text-muted-foreground uppercase">{group.label}</p>
          {group.items.map((item) => {
            const isActive = item.href === current.href;
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={onNavigate}
                aria-current={isActive ? "page" : undefined}
                className={cn(
                  "flex items-center gap-3 rounded-lg px-3 py-1.5 text-sm font-medium text-navy-700 transition-colors hover:bg-muted hover:text-navy-900",
                  isActive && "bg-coral-50 text-coral-600 hover:bg-coral-50 hover:text-coral-600",
                )}
              >
                <Icon className="size-4.5" aria-hidden />
                <span className="flex-1">{item.label}</span>
                {badges?.[item.href]}
              </Link>
            );
          })}
        </div>
      ))}
    </nav>
  );
}

function TopSearch({ pathname }: { pathname: string }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const section = activeNav(pathname);
  // Search the open list page, otherwise drivers (the most common lookup).
  const target = section.searchHint && pathname === section.href ? section : DEFAULT_SEARCH;
  const urlValue = pathname === target.href ? (searchParams.get("q") ?? "") : "";
  const [value, setValue] = useState(urlValue);
  const [prevUrlValue, setPrevUrlValue] = useState(urlValue);
  if (urlValue !== prevUrlValue) {
    setPrevUrlValue(urlValue);
    setValue(urlValue);
  }

  return (
    <form
      role="search"
      className="relative hidden w-full max-w-sm md:block"
      onSubmit={(e) => {
        e.preventDefault();
        const params = new URLSearchParams(pathname === target.href ? searchParams.toString() : "");
        params.delete("page");
        if (value.trim()) params.set("q", value.trim());
        else params.delete("q");
        const qs = params.toString();
        router.push(qs ? `${target.href}?${qs}` : target.href);
      }}
    >
      <SearchIcon className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground" />
      <Input
        type="search"
        aria-label={target.searchHint}
        placeholder={target.searchHint}
        value={value}
        onChange={(e) => setValue(e.target.value)}
        className="h-9 bg-muted/60 pl-9"
      />
    </form>
  );
}

/** Sidebar (desktop) / sheet (mobile) + top bar around every signed-in page. */
export function AppShell({
  userMenu,
  badges,
  children,
}: {
  userMenu: React.ReactNode;
  /** Server-rendered counters next to nav items, keyed by href (e.g. pending KYC). */
  badges?: Record<string, React.ReactNode>;
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const [isMenuOpen, setMenuOpen] = useState(false);
  const section = activeNav(pathname);

  return (
    <div className="min-h-screen lg:grid lg:grid-cols-[240px_1fr]">
      <aside className="sticky top-0 hidden h-screen flex-col overflow-y-auto border-r bg-sidebar px-4 py-6 lg:flex">
        <Link href="/" className="mb-6 px-3" aria-label="Rido admin home">
          <Wordmark className="text-[28px]" />
          <span className="mt-1 block text-xs font-medium tracking-wide text-muted-foreground uppercase">Admin</span>
        </Link>
        <SidebarNav pathname={pathname} badges={badges} />
        <p className="mt-auto px-3 pt-6 text-xs text-muted-foreground">Zero-commission rides &amp; parcels · Coimbatore</p>
      </aside>

      <Sheet open={isMenuOpen} onOpenChange={setMenuOpen}>
        <SheetContent side="left" className="w-72 overflow-y-auto px-4 py-6">
          <SheetHeader className="mb-4 p-0 px-3">
            <SheetTitle>
              <Wordmark className="text-[28px]" />
            </SheetTitle>
            <SheetDescription>Admin</SheetDescription>
          </SheetHeader>
          <SidebarNav pathname={pathname} badges={badges} onNavigate={() => setMenuOpen(false)} />
        </SheetContent>
      </Sheet>

      <div className="flex min-w-0 flex-col">
        <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b bg-card/95 px-4 backdrop-blur sm:px-6">
          <Button variant="ghost" size="icon" className="lg:hidden" aria-label="Open menu" onClick={() => setMenuOpen(true)}>
            <MenuIcon />
          </Button>
          <p className="font-heading text-lg font-semibold text-navy-900 lg:hidden">{section.label}</p>
          <Suspense fallback={<div className="hidden h-9 w-full max-w-sm rounded-lg bg-muted/60 md:block" />}>
            <TopSearch pathname={pathname} />
          </Suspense>
          <div className="ml-auto">{userMenu}</div>
        </header>
        <main className="mx-auto w-full max-w-7xl flex-1 px-4 py-6 sm:px-6 lg:py-8">{children}</main>
      </div>
    </div>
  );
}
