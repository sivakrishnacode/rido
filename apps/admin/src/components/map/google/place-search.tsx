"use client";

import { Loader2Icon, MapPinIcon, SearchIcon, XIcon } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { cn } from "@/lib/utils";

export interface FoundPlace {
  readonly placeId: string;
  readonly name: string;
  readonly address: string;
  readonly lat: number;
  readonly lng: number;
}

interface Suggestion {
  readonly placeId: string;
  readonly name: string;
  readonly address: string;
}

function newSession(): string {
  return typeof crypto !== "undefined" && "randomUUID" in crypto ? crypto.randomUUID() : String(Date.now());
}

/**
 * Locality search over the Rido API (Google Places Autocomplete with the server key, cached in Redis).
 * Debounced 300 ms, ≥ 3 characters, one session token per search that ends with the details call.
 */
export function PlaceSearch({ onSelect, className }: { onSelect: (place: FoundPlace) => void; className?: string }) {
  const [q, setQ] = useState("");
  const [results, setResults] = useState<Suggestion[]>([]);
  const [isOpen, setOpen] = useState(false);
  const [isLoading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [active, setActive] = useState(0);
  const session = useRef<string>("");
  const request = useRef(0);

  useEffect(() => {
    const term = q.trim();
    if (term.length < 3) return;
    const id = ++request.current;
    const timer = setTimeout(async () => {
      if (!session.current) session.current = newSession();
      setLoading(true);
      try {
        const res = await fetch(`/api/places?q=${encodeURIComponent(term)}&session=${session.current}`, { cache: "no-store" });
        if (!res.ok) throw new Error(res.status === 401 ? "Signed out" : "Search failed");
        const body = (await res.json()) as { results?: Suggestion[] };
        if (id !== request.current) return;
        setResults(body.results ?? []);
        setActive(0);
        setError(null);
        setOpen(true);
      } catch (e) {
        if (id === request.current) setError(e instanceof Error ? e.message : "Search failed");
      } finally {
        if (id === request.current) setLoading(false);
      }
    }, 300);
    return () => clearTimeout(timer);
  }, [q]);

  async function choose(s: Suggestion) {
    setOpen(false);
    setLoading(true);
    try {
      const res = await fetch(`/api/places/${encodeURIComponent(s.placeId)}?session=${session.current}`, { cache: "no-store" });
      if (!res.ok) throw new Error("Couldn't find that place");
      const place = (await res.json()) as FoundPlace;
      setQ(s.name);
      setError(null);
      onSelect({ ...place, name: s.name });
    } catch (e) {
      setError(e instanceof Error ? e.message : "Lookup failed");
    } finally {
      session.current = ""; // details ends the billing session
      setLoading(false);
    }
  }

  return (
    <div className={cn("relative w-72 max-w-[calc(100vw-5rem)]", className)}>
      <div className="flex h-10 items-center gap-2 rounded-lg border bg-card px-3 shadow-md">
        {isLoading ? <Loader2Icon className="size-4 animate-spin text-muted-foreground" /> : <SearchIcon className="size-4 text-muted-foreground" />}
        <input
          type="text"
          value={q}
          placeholder="Find a locality, e.g. Peelamedu"
          role="combobox"
          aria-autocomplete="list"
          aria-label="Find a place on the map"
          aria-expanded={isOpen}
          aria-controls="place-results"
          className="h-full flex-1 bg-transparent text-sm outline-none placeholder:text-muted-foreground"
          onChange={(e) => {
            setQ(e.target.value);
            if (e.target.value.trim().length < 3) {
              setResults([]);
              setOpen(false);
            }
          }}
          onFocus={() => results.length > 0 && setOpen(true)}
          onKeyDown={(e) => {
            e.stopPropagation(); // keep editor shortcuts (P, E, [ …) out of the search box
            if (e.key === "ArrowDown") setActive((a) => Math.min(a + 1, results.length - 1));
            else if (e.key === "ArrowUp") setActive((a) => Math.max(a - 1, 0));
            else if (e.key === "Enter" && results[active]) {
              e.preventDefault();
              void choose(results[active]);
            } else if (e.key === "Escape") setOpen(false);
          }}
        />
        {q && (
          <button
            type="button"
            aria-label="Clear search"
            className="text-muted-foreground hover:text-foreground"
            onClick={() => {
              setQ("");
              setResults([]);
              setOpen(false);
            }}
          >
            <XIcon className="size-4" />
          </button>
        )}
      </div>
      {error && <p className="mt-1 rounded-md bg-card px-2 py-1 text-xs text-error shadow">{error}</p>}
      {isOpen && (
        <ul id="place-results" role="listbox" className="mt-1 max-h-72 overflow-y-auto rounded-lg border bg-card py-1 shadow-lg">
          {results.length === 0 ? (
            <li className="px-3 py-2 text-sm text-muted-foreground">No places found</li>
          ) : (
            results.map((r, i) => (
              <li key={r.placeId} role="option" aria-selected={i === active}>
                <button
                  type="button"
                  onMouseEnter={() => setActive(i)}
                  onClick={() => void choose(r)}
                  className={cn("flex w-full items-start gap-2 px-3 py-2 text-left", i === active && "bg-coral-50")}
                >
                  <MapPinIcon className="mt-0.5 size-4 shrink-0 text-coral-600" />
                  <span className="min-w-0">
                    <span className="block truncate text-sm font-medium text-navy-900">{r.name}</span>
                    <span className="block truncate text-xs text-muted-foreground">{r.address}</span>
                  </span>
                </button>
              </li>
            ))
          )}
        </ul>
      )}
    </div>
  );
}
