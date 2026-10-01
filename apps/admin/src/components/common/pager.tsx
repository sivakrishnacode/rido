import { ChevronLeftIcon, ChevronRightIcon } from "lucide-react";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import { Pagination, PaginationContent, PaginationEllipsis, PaginationItem } from "@/components/ui/pagination";
import { formatCount } from "@/lib/format";
import { PAGE_SIZES, pageHref, pageInfo, pageSizeParam, pageWindow, withQuery, type QueryInput } from "@/lib/paging";
import { cn } from "@/lib/utils";

/**
 * "Showing 1–20 of 57" + page links that keep the current filters, and (with [canResize]) a 20 / 50 / 100 rows choice
 * kept in ?pageSize. Pass the page size in [query] too (`pageSizeParam`) so page links keep it.
 */
export function Pager({
  path,
  query,
  page,
  pageSize,
  total,
  noun = "results",
  canResize = false,
}: {
  path: string;
  query: QueryInput;
  page: number;
  pageSize: number;
  total: number;
  noun?: string;
  canResize?: boolean;
}) {
  const info = pageInfo({ page, pageSize, total });
  if (total === 0) return null;
  return (
    <div className="flex flex-col items-center justify-between gap-3 border-t px-4 py-3 sm:flex-row">
      <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-muted-foreground">
        <p>
          Showing <span className="font-medium text-navy-900">{formatCount(info.from)}</span>–
          <span className="font-medium text-navy-900">{formatCount(info.to)}</span> of{" "}
          <span className="font-medium text-navy-900">{formatCount(total)}</span> {noun}
        </p>
        {canResize && total > PAGE_SIZES[0] && (
          <p className="flex items-center gap-1" aria-label="Rows per page">
            Rows
            {PAGE_SIZES.map((size) => (
              <Link
                key={size}
                href={withQuery(path, { ...query, page: undefined, pageSize: pageSizeParam(size) })}
                aria-current={size === pageSize ? "true" : undefined}
                className={cn(
                  "rounded-md px-1.5 py-0.5 tabular-nums hover:bg-muted hover:text-navy-900",
                  size === pageSize && "bg-muted font-semibold text-navy-900",
                )}
              >
                {size}
              </Link>
            ))}
          </p>
        )}
      </div>
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
