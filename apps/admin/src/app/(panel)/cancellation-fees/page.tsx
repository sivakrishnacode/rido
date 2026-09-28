import { ReceiptIndianRupeeIcon } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";

import { ListFilters } from "@/components/common/list-filters";
import { EmptyState, PageHeader } from "@/components/common/page";
import { Pager } from "@/components/common/pager";
import { PlateBadge } from "@/components/common/status";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { adminApi } from "@/lib/api";
import { displayName, formatCount, formatDateTime, formatInr, formatPhone, humanize, shortId } from "@/lib/format";
import { DEFAULT_PAGE_SIZE, param, parsePage } from "@/lib/paging";
import { DUE_STATUSES } from "@/lib/types";

export const metadata: Metadata = { title: "Cancellation fees" };

/**
 * Report of cancellation fees (Settings › Cancellation fee, off by default): which passenger owed which driver, for
 * which cancelled trip, and the ride that collected it. No settlement: the collecting driver keeps the cash.
 */
export default async function CancellationFeesPage({ searchParams }: PageProps<"/cancellation-fees">) {
  const sp = await searchParams;
  const query = { status: param(sp.status) };
  const page = parsePage(sp.page);
  const data = await adminApi.cancellationDues({ ...query, page, pageSize: DEFAULT_PAGE_SIZE });

  return (
    <>
      <PageHeader
        title="Cancellation fees"
        description={`${formatCount(data.total)} fees · ${formatInr(data.totals.pending)} not collected yet · ${formatInr(data.totals.applied)} added to later rides. Report only: there is no settlement between drivers.`}
      />
      <ListFilters filters={[{ name: "status", label: "Statuses", options: DUE_STATUSES.map((s) => ({ value: s, label: s === "APPLIED" ? "Collected" : "Not collected" })) }]} />
      <Card className="gap-0 py-0">
        {data.items.length === 0 ? (
          <EmptyState
            icon={ReceiptIndianRupeeIcon}
            title={query.status ? "No fees with this status" : "No cancellation fees"}
            description="Fees are recorded only while Settings › Cancellation fee is on."
          />
        ) : (
          <Table>
            <TableHeader>
              <TableRow className="bg-muted/40 hover:bg-muted/40">
                <TableHead className="pl-4">Cancelled</TableHead>
                <TableHead>Passenger</TableHead>
                <TableHead>Owed to</TableHead>
                <TableHead className="text-right">Amount</TableHead>
                <TableHead className="pr-4">Collected on</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.items.map((d) => (
                <TableRow key={d.id}>
                  <TableCell className="pl-4 whitespace-nowrap">
                    <Link href={`/trips/${d.trip.id}`} className="font-mono text-xs text-navy-900 hover:text-coral-600">
                      #{shortId(d.trip.id)}
                    </Link>
                    <span className="block text-xs text-muted-foreground">{formatDateTime(d.trip.cancelledAt ?? d.createdAt)}</span>
                  </TableCell>
                  <TableCell>
                    <Link href={`/users/${d.passenger.id}`} className="font-medium text-navy-900 hover:text-coral-600">
                      {displayName(d.passenger)}
                    </Link>
                    <span className="block text-xs text-muted-foreground">{formatPhone(d.passenger.phone)}</span>
                  </TableCell>
                  <TableCell>
                    <Link href={`/drivers/${d.owedTo.id}`} className="font-medium text-navy-900 hover:text-coral-600">
                      {displayName(d.owedTo.user)}
                    </Link>
                    <span className="mt-0.5 block">
                      <PlateBadge plate={d.owedTo.plate} />
                    </span>
                  </TableCell>
                  <TableCell className="text-right font-medium tabular-nums">{formatInr(d.amount)}</TableCell>
                  <TableCell className="pr-4">
                    {d.appliedTrip ? (
                      <>
                        <Link href={`/trips/${d.appliedTrip.id}`} className="font-mono text-xs text-navy-900 hover:text-coral-600">
                          #{shortId(d.appliedTrip.id)}
                        </Link>
                        <span className="block text-xs text-muted-foreground">
                          {d.appliedTrip.driver ? `by ${displayName(d.appliedTrip.driver.user)}` : ""}
                          {d.appliedAt ? ` · ${formatDateTime(d.appliedAt)}` : ""}
                        </span>
                      </>
                    ) : (
                      <span className="text-muted-foreground">{humanize("NOT_COLLECTED_YET")}</span>
                    )}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
        <Pager path="/cancellation-fees" query={query} page={data.page} pageSize={data.pageSize} total={data.total} noun="fees" />
      </Card>
    </>
  );
}
