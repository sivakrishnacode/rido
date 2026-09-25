import { ChevronLeftIcon, ChevronRightIcon } from "lucide-react";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import { Pagination, PaginationContent, PaginationEllipsis, PaginationItem } from "@/components/ui/pagination";
import { formatCount } from "@/lib/format";
import { pageHref, pageInfo, pageWindow, type QueryInput } from "@/lib/paging";

/** "Showing 1–20 of 57" + page links that keep the current filters. */
export function Pager({
  path,
  query,
  page,
  pageSize,
  total,
  noun = "results",
}: {
  path: string;
  query: QueryInput;
  page: number;
  pageSize: number;
  total: number;
  noun?: string;
}) {
  const info = pageInfo({ page, pageSize, total });
  if (total === 0) return null;
  return (
    <div className="flex flex-col items-center justify-between gap-3 border-t px-4 py-3 sm:flex-row">
      <p className="text-sm text-muted-foreground">
        Showing <span className="font-medium text-navy-900">{formatCount(info.from)}</span>–
        <span className="font-medium text-navy-900">{formatCount(info.to)}</span> of{" "}
        <span className="font-medium text-navy-900">{formatCount(total)}</span> {noun}
      </p>
      {info.pageCount > 1 && (
        <Pagination className="mx-0 w-auto">
          <PaginationContent>
            <PaginationItem>
              <Button asChild={info.hasPrev} variant="ghost" size="sm" disabled={!info.hasPrev} aria-label="Previous page">
                {info.hasPrev ? (
                  <Link href={pageHref(path, query, page - 1)}>
                    <ChevronLeftIcon /> <span className="hidden sm:inline">Previous</span>
                  </Link>
                ) : (
                  <span>
                    <ChevronLeftIcon /> <span className="hidden sm:inline">Previous</span>
                  </span>
                )}
              </Button>
            </PaginationItem>
            {pageWindow(page, info.pageCount).map((p, i) =>
              p === "…" ? (
                <PaginationItem key={`gap-${i}`}>
                  <PaginationEllipsis />
                </PaginationItem>
              ) : (
                <PaginationItem key={p}>
                  <Button asChild variant={p === page ? "outline" : "ghost"} size="icon-sm">
                    <Link href={pageHref(path, query, p)} aria-current={p === page ? "page" : undefined}>
                      {p}
                    </Link>
                  </Button>
                </PaginationItem>
              ),
            )}
            <PaginationItem>
              <Button asChild={info.hasNext} variant="ghost" size="sm" disabled={!info.hasNext} aria-label="Next page">
                {info.hasNext ? (
                  <Link href={pageHref(path, query, page + 1)}>
                    <span className="hidden sm:inline">Next</span> <ChevronRightIcon />
                  </Link>
                ) : (
                  <span>
                    <span className="hidden sm:inline">Next</span> <ChevronRightIcon />
                  </span>
                )}
              </Button>
            </PaginationItem>
          </PaginationContent>
        </Pagination>
      )}
    </div>
  );
}
