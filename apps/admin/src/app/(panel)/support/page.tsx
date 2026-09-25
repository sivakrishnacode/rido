import { LifeBuoyIcon } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";

import { ListFilters } from "@/components/common/list-filters";
import { EmptyState, PageHeader } from "@/components/common/page";
import { Pager } from "@/components/common/pager";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { adminApi } from "@/lib/api";
import { displayName, formatCount, formatDateTime, formatPhone, humanize, shortId } from "@/lib/format";
import { DEFAULT_PAGE_SIZE, param, parsePage } from "@/lib/paging";
import { TICKET_STATUSES } from "@/lib/types";

import { TicketStatusSelect } from "./ticket-status-select";

export const metadata: Metadata = { title: "Support" };

export default async function SupportPage({ searchParams }: PageProps<"/support">) {
  const sp = await searchParams;
  const query = { status: param(sp.status) };
  const page = parsePage(sp.page);
  const data = await adminApi.tickets({ ...query, page, pageSize: DEFAULT_PAGE_SIZE });

  return (
    <>
      <PageHeader title="Support" description={`${formatCount(data.total)} ${query.status ? humanize(query.status).toLowerCase() : ""} tickets from passengers and drivers.`} />
      <ListFilters filters={[{ name: "status", label: "Statuses", options: TICKET_STATUSES.map((s) => ({ value: s, label: humanize(s) })) }]} />
      <Card className="gap-0 py-0">
        {data.items.length === 0 ? (
          <EmptyState
            icon={LifeBuoyIcon}
            title={query.status ? "No tickets with this status" : "No support tickets"}
            description="Tickets raised from the Help screens in both apps appear here."
          />
        ) : (
          <Table>
            <TableHeader>
              <TableRow className="bg-muted/40 hover:bg-muted/40">
                <TableHead className="pl-4">Raised</TableHead>
                <TableHead>From</TableHead>
                <TableHead>Topic</TableHead>
                <TableHead>Trip</TableHead>
                <TableHead className="pr-4">Status</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.items.map((t) => (
                <TableRow key={t.id}>
                  <TableCell className="pl-4 whitespace-nowrap text-navy-700">{formatDateTime(t.createdAt)}</TableCell>
                  <TableCell>
                    <Link href={`/users/${t.user.id}`} className="font-medium text-navy-900 hover:text-coral-600">
                      {displayName(t.user)}
                    </Link>
                    <span className="block text-xs text-muted-foreground">
                      {formatPhone(t.user.phone)} · {humanize(t.user.role)}
                    </span>
                  </TableCell>
                  <TableCell className="max-w-md whitespace-normal">
                    <span className="block font-medium text-navy-900">{t.topic}</span>
                    <span className="line-clamp-2 text-sm text-navy-700">{t.description}</span>
                  </TableCell>
                  <TableCell>
                    {t.trip ? (
                      <Link href={`/trips/${t.trip.id}`} className="font-mono text-xs font-medium text-coral-600 hover:underline">
                        #{shortId(t.trip.id)}
                      </Link>
                    ) : (
                      <span className="text-muted-foreground">–</span>
                    )}
                  </TableCell>
                  <TableCell className="pr-4">
                    <TicketStatusSelect ticketId={t.id} status={t.status} />
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
        <Pager path="/support" query={query} page={data.page} pageSize={data.pageSize} total={data.total} noun="tickets" />
      </Card>
    </>
  );
}
