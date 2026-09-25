import { IdCardIcon } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";

import { ExportButton } from "@/components/common/export-button";
import { ListFilters } from "@/components/common/list-filters";
import { EmptyState, PageHeader } from "@/components/common/page";
import { Pager } from "@/components/common/pager";
import { KycProgress, OnlineDot, PlateBadge, StatusBadge } from "@/components/common/status";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { adminApi } from "@/lib/api";
import { displayName, formatCount, formatDate, formatPhone, humanize, initials, kycProgress, vehicleLabel } from "@/lib/format";
import { DEFAULT_PAGE_SIZE, param, parsePage } from "@/lib/paging";
import { DRIVER_STATUSES } from "@/lib/types";

export const metadata: Metadata = { title: "Drivers" };

export default async function DriversPage({ searchParams }: PageProps<"/drivers">) {
  const sp = await searchParams;
  const query = { q: param(sp.q), status: param(sp.status) };
  const page = parsePage(sp.page);
  const data = await adminApi.drivers({ ...query, page, pageSize: DEFAULT_PAGE_SIZE });
  const isFiltered = !!(query.q || query.status);

  return (
    <>
      <PageHeader
        title="Drivers"
        description={`${formatCount(data.total)} ${isFiltered ? "matching" : "registered"} drivers. Review KYC, approve or put accounts on hold.`}
        actions={<ExportButton entity="drivers" />}
      />
      <ListFilters
        searchPlaceholder="Name, phone or plate"
        filters={[{ name: "status", label: "Statuses", options: DRIVER_STATUSES.map((s) => ({ value: s, label: humanize(s) })) }]}
      />
      <Card className="gap-0 py-0">
        {data.items.length === 0 ? (
          <EmptyState
            icon={IdCardIcon}
            title={isFiltered ? "No drivers match" : "No drivers yet"}
            description={isFiltered ? "Try another name, phone number or status." : "Drivers appear here once they register in the Rido Driver app."}
          />
        ) : (
          <Table>
            <TableHeader>
              <TableRow className="bg-muted/40 hover:bg-muted/40">
                <TableHead className="pl-4">Driver</TableHead>
                <TableHead>Phone</TableHead>
                <TableHead>Vehicle</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>KYC</TableHead>
                <TableHead>Plan</TableHead>
                <TableHead className="text-center">Online</TableHead>
                <TableHead className="pr-4">Joined</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.items.map((d) => {
                const kyc = kycProgress(d.documents);
                const sub = d.subscriptions[0];
                return (
                  <TableRow key={d.id} className="relative">
                    <TableCell className="pl-4">
                      <Link
                        href={`/drivers/${d.id}`}
                        className="flex items-center gap-2.5 font-medium text-navy-900 after:absolute after:inset-0 hover:text-coral-600"
                      >
                        <Avatar className="size-8">
                          <AvatarFallback className="bg-coral-50 text-xs font-semibold text-coral-600">
                            {initials(d.user.name)}
                          </AvatarFallback>
                        </Avatar>
                        {displayName(d.user)}
                      </Link>
                    </TableCell>
                    <TableCell className="text-navy-700 tabular-nums">{formatPhone(d.user.phone)}</TableCell>
                    <TableCell>
                      <span className="flex flex-col gap-1">
                        <span className="text-xs text-muted-foreground">
                          {vehicleLabel(d.vehicleKind)} · {d.vehicleModel}
                        </span>
                        <PlateBadge plate={d.plate} />
                      </span>
                    </TableCell>
                    <TableCell>
                      <StatusBadge status={d.status} />
                    </TableCell>
                    <TableCell>
                      <KycProgress verified={kyc.verified} total={kyc.total} />
                    </TableCell>
                    <TableCell>
                      {sub ? (
                        <span className="flex flex-col items-start gap-1">
                          <StatusBadge status={sub.status} />
                          <span className="text-xs text-muted-foreground">{humanize(sub.plan.period)}</span>
                        </span>
                      ) : (
                        <span className="text-xs text-muted-foreground">No plan</span>
                      )}
                    </TableCell>
                    <TableCell className="text-center">
                      <OnlineDot isOnline={d.isOnline} />
                    </TableCell>
                    <TableCell className="pr-4 text-navy-700">{formatDate(d.createdAt)}</TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        )}
        <Pager path="/drivers" query={query} page={data.page} pageSize={data.pageSize} total={data.total} noun="drivers" />
      </Card>
    </>
  );
}
