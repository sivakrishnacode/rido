import { ShieldAlertIcon } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";

import { ListFilters } from "@/components/common/list-filters";
import { EmptyState, PageHeader } from "@/components/common/page";
import { Pager } from "@/components/common/pager";
import { PlateBadge, StatusBadge } from "@/components/common/status";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { adminApi } from "@/lib/api";
import { displayName, formatCount, formatDateTime, formatPhone, humanize, shortId } from "@/lib/format";
import { DEFAULT_PAGE_SIZE, param, parsePage } from "@/lib/paging";
import { SOS_REFRESH_MS, SOS_STATUSES, sosMapUrl, sosSourceLabel } from "@/lib/safety";
import { cn } from "@/lib/utils";

import { AutoRefresh } from "./auto-refresh";
import { SosActions } from "./sos-actions";

export const metadata: Metadata = { title: "SOS" };

export default async function SafetyPage({ searchParams }: PageProps<"/safety">) {
  const sp = await searchParams;
  const query = { status: param(sp.status) };
  const page = parsePage(sp.page);
  const data = await adminApi.sos({ ...query, page, pageSize: DEFAULT_PAGE_SIZE });

  return (
    <>
      <AutoRefresh ms={SOS_REFRESH_MS} />
      <PageHeader
        title="SOS"
        description={`${formatCount(data.open)} open · ${formatCount(data.total)} ${query.status ? humanize(query.status).toLowerCase() : ""} alerts from riders and drivers. Refreshes every 10 s; admins' phones also get a push.`}
      />
      <ListFilters
        filters={[
          {
            name: "status",
            label: "Statuses",
            options: [{ value: "active", label: "Open + acknowledged" }, ...SOS_STATUSES.map((s) => ({ value: s, label: humanize(s) }))],
          },
        ]}
      />
      <Card className="gap-0 py-0">
        {data.items.length === 0 ? (
          <EmptyState icon={ShieldAlertIcon} title="No SOS alerts" description="SOS from the passenger and driver apps appear here at once." />
        ) : (
          <Table>
            <TableHeader>
              <TableRow className="bg-muted/40 hover:bg-muted/40">
                <TableHead className="pl-4">Raised</TableHead>
                <TableHead>Who</TableHead>
                <TableHead>Trip</TableHead>
                <TableHead className="pr-4">Status</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.items.map((s) => {
                const map = sosMapUrl(s);
                const isOpen = s.status === "OPEN";
                const other = s.role === "PASSENGER" ? s.trip.driver?.user : s.trip.passenger;
                return (
                  <TableRow key={s.id} className={cn(isOpen && "bg-error-tint/60 hover:bg-error-tint")}>
                    <TableCell className="pl-4 whitespace-nowrap">
                      <span className={cn("block", isOpen ? "font-semibold text-error" : "text-navy-700")}>{formatDateTime(s.createdAt)}</span>
                      <span className="block text-xs text-muted-foreground">{sosSourceLabel(s.source)}</span>
                      {map ? (
                        <a href={map} target="_blank" rel="noreferrer" className="relative z-10 text-xs font-medium text-coral-600 hover:underline">
                          Where: open map
                        </a>
                      ) : (
                        <span className="text-xs text-muted-foreground">Where: unknown</span>
                      )}
                    </TableCell>
                    <TableCell className="max-w-64 whitespace-normal">
                      <Link href={`/users/${s.user.id}`} className="font-medium text-navy-900 hover:text-coral-600">
                        {displayName(s.user)}
                      </Link>
                      <span className="block text-xs text-muted-foreground">
                        {humanize(s.role)} · {formatPhone(s.user.phone)}
                      </span>
                      {other && (
                        <span className="block text-xs text-muted-foreground">
                          {s.role === "PASSENGER" ? "Driver" : "Passenger"}: {displayName(other)} · {formatPhone(other.phone)}
                        </span>
                      )}
                    </TableCell>
                    <TableCell className="max-w-64 whitespace-normal">
                      <Link href={`/trips/${s.trip.id}`} className="font-mono text-xs font-medium text-coral-600 hover:underline">
                        #{shortId(s.trip.id)}
                      </Link>{" "}
                      <StatusBadge status={s.trip.status} className="ml-1" />
                      <span className="block line-clamp-2 text-xs text-navy-700">
                        {s.trip.pickupName} → {s.trip.dropName}
                      </span>
                      {s.trip.driver && <PlateBadge plate={s.trip.driver.plate} className="mt-1" />}
                    </TableCell>
                    <TableCell className="max-w-60 min-w-44 space-y-2 pr-4 whitespace-normal">
                      <StatusBadge status={s.status} className={cn(isOpen && "bg-error text-white")} />
                      {s.note && <span className="block line-clamp-2 text-xs text-navy-700">{s.note}</span>}
                      <SosActions id={s.id} tripId={s.trip.id} status={s.status} />
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        )}
        <Pager path="/safety" query={query} page={data.page} pageSize={data.pageSize} total={data.total} noun="alerts" />
      </Card>
    </>
  );
}
