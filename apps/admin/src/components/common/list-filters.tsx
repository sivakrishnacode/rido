"use client";

import { Loader2Icon, SearchIcon, XIcon } from "lucide-react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useRef, useState, useTransition } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

export interface FilterDef {
  readonly name: string;
  readonly label: string;
  readonly options: readonly { value: string; label: string }[];
}

/** Search box + select filters bound to the URL (?q, ?status, ?kind). Changing any of them resets ?page. */
export function ListFilters({
  searchPlaceholder,
  filters = [],
}: {
  searchPlaceholder?: string;
  filters?: readonly FilterDef[];
}) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [isPending, startTransition] = useTransition();
  const [q, setQ] = useState(searchParams.get("q") ?? "");
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Keep the box in sync when the URL changes elsewhere (top-bar search, back button).
  const urlQ = searchParams.get("q") ?? "";
  const [prevUrlQ, setPrevUrlQ] = useState(urlQ);
  if (urlQ !== prevUrlQ) {
    setPrevUrlQ(urlQ);
    setQ(urlQ);
  }

  function update(changes: Record<string, string | null>) {
    const params = new URLSearchParams(searchParams.toString());
    for (const [key, value] of Object.entries(changes)) {
      if (value && value !== "ALL") params.set(key, value);
      else params.delete(key);
    }
    params.delete("page");
    const qs = params.toString();
    startTransition(() => router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false }));
  }

  function onSearch(value: string) {
    setQ(value);
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => update({ q: value.trim() || null }), 350);
  }

  const hasFilters = !!searchParams.get("q") || filters.some((f) => searchParams.get(f.name));

  return (
    <div className="mb-4 flex flex-col gap-2 sm:flex-row sm:flex-wrap sm:items-center">
      {searchPlaceholder !== undefined && (
        <div className="relative w-full sm:w-72">
          <SearchIcon className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            type="search"
            value={q}
            onChange={(e) => onSearch(e.target.value)}
            placeholder={searchPlaceholder}
            aria-label={searchPlaceholder}
            className="h-9 bg-card pl-9"
          />
        </div>
      )}
      {filters.map((f) => (
        <Select key={f.name} value={searchParams.get(f.name) ?? "ALL"} onValueChange={(v) => update({ [f.name]: v })}>
          <SelectTrigger className="h-9 w-full bg-card sm:w-44" aria-label={f.label}>
            <SelectValue placeholder={f.label} />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="ALL">All {f.label.toLowerCase()}</SelectItem>
            {f.options.map((o) => (
              <SelectItem key={o.value} value={o.value}>
                {o.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      ))}
      {hasFilters && (
        <Button
          variant="ghost"
          size="sm"
          className="h-9 text-muted-foreground"
          onClick={() => {
            setQ("");
            update(Object.fromEntries([["q", null], ...filters.map((f) => [f.name, null])]));
          }}
        >
          <XIcon /> Clear
        </Button>
      )}
      {isPending && <Loader2Icon className="size-4 animate-spin text-muted-foreground" aria-label="Updating" />}
    </div>
  );
}
