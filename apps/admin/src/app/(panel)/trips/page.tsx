import { PackageIcon, RouteIcon } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";

import { ExportButton } from "@/components/common/export-button";
import { ListFilters } from "@/components/common/list-filters";
import { EmptyState, PageHeader } from "@/components/common/page";
import { Pager } from "@/components/common/pager";
import { StatusBadge } from "@/components/common/status";
import { TripRouteCell } from "@/components/common/trip-bits";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { adminApi } from "@/lib/api";
import { displayName, formatCount, formatDate, formatInr, formatTime, humanize, shortId, vehicleLabel } from "@/lib/format";
import { DEFAULT_PAGE_SIZE, param, parsePage } from "@/lib/paging";
import { TRIP_STATUSES } from "@/lib/types";

export const metadata: Metadata = { title: "Trips" };

export default async function TripsPage({ searchParams }: PageProps<"/trips">) {
  const sp = await searchParams;
  const query = { q: param(sp.q), status: param(sp.status), kind: param(sp.kind) };
  const page = parsePage(sp.page);
  const data = await adminApi.trips({ ...query, page, pageSize: DEFAULT_PAGE_SIZE });
  const isFiltered = !!(query.q || query.status || query.kind);

  return (
    <>
      <PageHeader
        title="Trips"
        description={`${formatCount(data.total)} ${isFiltered ? "matching" : ""} rides and parcel deliveries, newest first.`}
        actions={<ExportButton entity="trips" />}
      />
      <ListFilters
        searchPlaceholder="Trip id, pickup or drop"
        filters={[
          { name: "kind", label: "Kinds", options: [{ value: "RIDE", label: "Rides" }, { value: "PARCEL", label: "Parcels" }] },
          { name: "status", label: "Statuses", options: TRIP_STATUSES.map((s) => ({ value: s, label: humanize(s) })) },
        ]}
      />
      <Card className="gap-0 py-0">
        {data.items.length === 0 ? (
          <EmptyState
            icon={RouteIcon}
            title={isFiltered ? "No trips match" : "No trips yet"}
            description={isFiltered ? "Try a different search or filter." : "Bookings from the Rido app appear here."}
          />
        ) : (
          <Table>
            <TableHeader>
              <TableRow className="bg-muted/40 hover:bg-muted/40">
                <TableHead className="pl-4">Trip</TableHead>
                <TableHead>When</TableHead>
                <TableHead>Vehicle</TableHead>
                <TableHead>Route</TableHead>
                <TableHead>Passenger</TableHead>
                <TableHead>Driver</TableHead>
                <TableHead className="text-right">Fare</TableHead>
                <TableHead className="pr-4">Status</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.items.map((t) => (
                <TableRow key={t.id} className="relative">
                  <TableCell className="pl-4">
                    <Link
                      href={`/trips/${t.id}`}
                      className="font-mono text-xs font-semibold text-navy-900 after:absolute after:inset-0 hover:text-coral-600"
                    >
                      #{shortId(t.id)}
                    </Link>
                    <span className="mt-0.5 flex items-center gap-1 text-xs text-muted-foreground">
                      {t.kind === "PARCEL" ? <PackageIcon className="size-3" /> : <RouteIcon className="size-3" />}
                      {t.kind === "PARCEL" ? "Parcel" : "Ride"}
                    </span>
                  </TableCell>
                  <TableCell className="whitespace-nowrap text-navy-700">
                    {formatDate(t.createdAt)}
                    <span className="block text-xs text-muted-foreground">{formatTime(t.createdAt)}</span>
                  </TableCell>
                  <TableCell>{vehicleLabel(t.vehicleKind)}</TableCell>
                  <TableCell>
                    <TripRouteCell pickup={t.pickupName} drop={t.dropName} />
                  </TableCell>
                  <TableCell>{displayName(t.passenger)}</TableCell>
                  <TableCell>{t.driver ? displayName(t.driver.user) : <span className="text-muted-foreground">–</span>}</TableCell>
                  <TableCell className="text-right font-medium tabular-nums">{formatInr(t.fareTotal)}</TableCell>
                  <TableCell className="pr-4">
                    <StatusBadge status={t.status} />
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
        <Pager path="/trips" query={query} page={data.page} pageSize={data.pageSize} total={data.total} noun="trips" />
      </Card>
    </>
  );
}
