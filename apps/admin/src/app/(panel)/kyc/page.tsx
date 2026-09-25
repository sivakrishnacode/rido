import { ClipboardCheckIcon, ExternalLinkIcon } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";

import { LinkTabs } from "@/components/common/link-tabs";
import { EmptyState, PageHeader } from "@/components/common/page";
import { Pager } from "@/components/common/pager";
import { PlateBadge, StatusBadge } from "@/components/common/status";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { adminApi } from "@/lib/api";
import { displayName, docLabel, formatCount, formatDateTime, formatPhone, humanize, vehicleLabel } from "@/lib/format";
import { DEFAULT_PAGE_SIZE, param, parsePage, withQuery } from "@/lib/paging";
import { KYC_STATUSES, type KycStatus } from "@/lib/types";

import { DocumentActions } from "../drivers/[id]/driver-actions";

export const metadata: Metadata = { title: "KYC" };

const TAB_LABEL: Record<KycStatus, string> = {
  UNDER_REVIEW: "Waiting for review",
  REJECTED: "Rejected",
  NOT_UPLOADED: "Not uploaded",
  VERIFIED: "Verified",
};

export default async function KycPage({ searchParams }: PageProps<"/kyc">) {
  const sp = await searchParams;
  const requested = param(sp.status) as KycStatus | undefined;
  const status: KycStatus = requested && KYC_STATUSES.includes(requested) ? requested : "UNDER_REVIEW";
  const page = parsePage(sp.page);
  const [data, pending] = await Promise.all([
    adminApi.kyc({ status, page, pageSize: DEFAULT_PAGE_SIZE }),
    status === "UNDER_REVIEW" ? null : adminApi.kyc({ status: "UNDER_REVIEW", pageSize: 1 }),
  ]);
  const pendingTotal = pending?.total ?? data.total;

  return (
    <>
      <PageHeader
        title="KYC review"
        description="Driver documents, oldest first. Verifying all five approves the driver; one rejection marks them rejected."
      />
      <LinkTabs
        active={status}
        tabs={KYC_STATUSES.map((s) => ({
          value: s,
          label: TAB_LABEL[s],
          href: withQuery("/kyc", { status: s === "UNDER_REVIEW" ? undefined : s }),
          count:
            s === "UNDER_REVIEW" && pendingTotal > 0 ? (
              <span className="rounded-full bg-coral-600 px-1.5 text-[11px] font-semibold text-white">{formatCount(pendingTotal)}</span>
            ) : undefined,
        }))}
      />
      <Card className="gap-0 py-0">
        {data.items.length === 0 ? (
          <EmptyState
            icon={ClipboardCheckIcon}
            title={status === "UNDER_REVIEW" ? "Queue is empty" : `No ${TAB_LABEL[status].toLowerCase()} documents`}
            description={
              status === "UNDER_REVIEW" ? "New uploads from the Rido Driver app land here for review." : "Nothing in this list right now."
            }
          />
        ) : (
          <Table>
            <TableHeader>
              <TableRow className="bg-muted/40 hover:bg-muted/40">
                <TableHead className="pl-4">Driver</TableHead>
                <TableHead>Vehicle</TableHead>
                <TableHead>Document</TableHead>
                <TableHead>Updated</TableHead>
                <TableHead className="pr-4 text-right">Review</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.items.map((doc) => (
                <TableRow key={doc.id}>
                  <TableCell className="pl-4">
                    <Link href={`/drivers/${doc.driverId}`} className="font-medium text-navy-900 hover:text-coral-600">
                      {displayName(doc.driver.user)}
                    </Link>
                    <span className="block text-xs text-muted-foreground">{formatPhone(doc.driver.user.phone)}</span>
                  </TableCell>
                  <TableCell>
                    <span className="flex flex-col gap-1">
                      <span className="text-xs text-muted-foreground">{vehicleLabel(doc.driver.vehicleKind)}</span>
                      <PlateBadge plate={doc.driver.plate} />
                    </span>
                  </TableCell>
                  <TableCell>
                    <span className="flex flex-wrap items-center gap-2 font-medium text-navy-900">
                      {docLabel(doc.type)} <StatusBadge status={doc.status} />
                    </span>
                    {doc.fileUrl && (
                      <a
                        href={doc.fileUrl}
                        target="_blank"
                        rel="noreferrer noopener"
                        className="mt-0.5 inline-flex items-center gap-0.5 text-xs text-coral-600 hover:underline"
                      >
                        View file <ExternalLinkIcon className="size-3" />
                      </a>
                    )}
                    {doc.status === "REJECTED" && doc.rejectReason && (
                      <span className="mt-0.5 block text-xs text-error">Reason: {doc.rejectReason}</span>
                    )}
                  </TableCell>
                  <TableCell className="whitespace-nowrap text-navy-700">{formatDateTime(doc.updatedAt)}</TableCell>
                  <TableCell className="pr-4">
                    <div className="flex justify-end">
                      <DocumentActions driverId={doc.driverId} type={doc.type} label={docLabel(doc.type)} status={doc.status} />
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
        <Pager path="/kyc" query={{ status: status === "UNDER_REVIEW" ? undefined : status }} page={data.page} pageSize={data.pageSize} total={data.total} noun={`${humanize(status).toLowerCase()} documents`} />
      </Card>
    </>
  );
}
