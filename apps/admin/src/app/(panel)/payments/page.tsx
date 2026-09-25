import { WalletCardsIcon } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";

import { ExportButton } from "@/components/common/export-button";
import { ListFilters } from "@/components/common/list-filters";
import { EmptyState, PageHeader } from "@/components/common/page";
import { Pager } from "@/components/common/pager";
import { StatusBadge } from "@/components/common/status";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { adminApi } from "@/lib/api";
import { displayName, formatCount, formatDateTime, formatInr, formatPhone, humanize, vehicleLabel } from "@/lib/format";
import { DEFAULT_PAGE_SIZE, param, parsePage } from "@/lib/paging";
import { PAYMENT_STATUSES } from "@/lib/types";

export const metadata: Metadata = { title: "Payments" };

export default async function PaymentsPage({ searchParams }: PageProps<"/payments">) {
  const sp = await searchParams;
  const query = { status: param(sp.status) };
  const page = parsePage(sp.page);
  const data = await adminApi.payments({ ...query, page, pageSize: DEFAULT_PAGE_SIZE });
  const pageSum = data.items.filter((p) => p.status === "PAID").reduce((a, p) => a + p.amount, 0);

  return (
    <>
      <PageHeader
        title="Payments"
        description={`${formatCount(data.total)} plan payments from drivers (UPI Autopay). Rido earns from plans only, never from fares.`}
        actions={<ExportButton entity="payments" />}
      />
      <ListFilters filters={[{ name: "status", label: "Statuses", options: PAYMENT_STATUSES.map((s) => ({ value: s, label: humanize(s) })) }]} />
      <Card className="gap-0 py-0">
        {data.items.length === 0 ? (
          <EmptyState
            icon={WalletCardsIcon}
            title={query.status ? "No payments with this status" : "No payments yet"}
            description="Drivers start paying once their free trial ends."
          />
        ) : (
          <Table>
            <TableHeader>
              <TableRow className="bg-muted/40 hover:bg-muted/40">
                <TableHead className="pl-4">Date</TableHead>
                <TableHead>Driver</TableHead>
                <TableHead>Plan</TableHead>
                <TableHead className="text-right">Amount</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="pr-4">Reference</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.items.map((p) => (
                <TableRow key={p.id}>
                  <TableCell className="pl-4 whitespace-nowrap text-navy-700">{formatDateTime(p.createdAt)}</TableCell>
                  <TableCell>
                    <Link href={`/drivers/${p.subscription.driverId}`} className="font-medium text-navy-900 hover:text-coral-600">
                      {displayName(p.subscription.driver.user)}
                    </Link>
                    <span className="block text-xs text-muted-foreground">{formatPhone(p.subscription.driver.user.phone)}</span>
                  </TableCell>
                  <TableCell>
                    {vehicleLabel(p.subscription.plan.vehicleKind)} · {humanize(p.subscription.plan.period)}
                  </TableCell>
                  <TableCell className="text-right font-medium tabular-nums">{formatInr(p.amount)}</TableCell>
                  <TableCell>
                    <StatusBadge status={p.status} />
                  </TableCell>
                  <TableCell className="pr-4">
                    <span className="font-mono text-xs text-navy-700">{p.providerRef ?? "–"}</span>
                    <span className="block text-xs text-muted-foreground">{p.provider}</span>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
        {data.items.length > 0 && (
          <p className="border-t px-4 py-2 text-right text-xs text-muted-foreground">
            Paid on this page: <span className="font-medium text-navy-900">{formatInr(pageSum)}</span>
          </p>
        )}
        <Pager path="/payments" query={query} page={data.page} pageSize={data.pageSize} total={data.total} noun="payments" />
      </Card>
    </>
  );
}
