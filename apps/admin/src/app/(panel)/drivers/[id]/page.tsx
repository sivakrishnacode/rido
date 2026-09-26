import { ArrowLeftIcon, ExternalLinkIcon, FileTextIcon, RouteIcon, StarIcon, WalletCardsIcon } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";

import { EmptyState, Field, PageHeader } from "@/components/common/page";
import { KycProgress, OnlineDot, PlateBadge, StatusBadge } from "@/components/common/status";
import { TripRouteCell } from "@/components/common/trip-bits";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { adminApi, docFileHref } from "@/lib/api";
import {
  displayName,
  docLabel,
  formatDate,
  formatDateTime,
  formatInr,
  formatPhone,
  humanize,
  initials,
  kycProgress,
  shortId,
  vehicleLabel,
} from "@/lib/format";
import { KYC_DOC_TYPES, type KycDocument } from "@/lib/types";

import { DocumentActions, DriverStatusActions } from "./driver-actions";

export async function generateMetadata({ params }: PageProps<"/drivers/[id]">): Promise<Metadata> {
  const { id } = await params;
  return { title: `Driver ${shortId(id)}` };
}

export default async function DriverPage({ params }: PageProps<"/drivers/[id]">) {
  const { id } = await params;
  const d = await adminApi.driver(id);
  const kyc = kycProgress(d.documents);
  const name = displayName(d.user);
  // Always list all 5 documents, even if the API has no row for one yet.
  const docs: KycDocument[] = KYC_DOC_TYPES.map(
    (type) =>
      d.documents.find((doc) => doc.type === type) ?? {
        id: type,
        driverId: d.id,
        type,
        status: "NOT_UPLOADED",
        rejectReason: null,
        fileUrl: null,
        updatedAt: d.createdAt,
      },
  );
  const payments = d.subscriptions.flatMap((s) => (s.payments ?? []).map((p) => ({ ...p, plan: s.plan })));

  return (
    <>
      <Link href="/drivers" className="mb-3 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeftIcon className="size-4" /> Drivers
      </Link>
      <PageHeader
        title={
          <span className="flex items-center gap-3">
            <Avatar className="size-12">
              <AvatarFallback className="bg-coral-50 text-base font-semibold text-coral-600">{initials(d.user.name)}</AvatarFallback>
            </Avatar>
            <span className="min-w-0">
              <span className="block truncate">{name}</span>
              <span className="mt-1 flex flex-wrap items-center gap-2 font-sans text-sm font-normal text-muted-foreground">
                <StatusBadge status={d.status} />
                <OnlineDot isOnline={d.isOnline} withLabel />
                <span>· {formatPhone(d.user.phone)}</span>
                <span>· joined {formatDate(d.createdAt)}</span>
              </span>
            </span>
          </span>
        }
        actions={<DriverStatusActions driverId={d.id} status={d.status} name={name} />}
      />

      <div className="grid gap-4 lg:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle className="font-semibold">Profile</CardTitle>
          </CardHeader>
          <CardContent>
            <dl className="grid grid-cols-2 gap-4">
              <Field label="Name">{d.user.name ?? "–"}</Field>
              <Field label="Phone">{formatPhone(d.user.phone)}</Field>
              <Field label="Email">{d.user.email ?? "–"}</Field>
              <Field label="Gender">{humanize(d.user.gender)}</Field>
              <Field label="Works on">{d.workType === "RIDES" ? "Rides" : "Deliveries"}</Field>
              <Field label="User">
                <Link href={`/users/${d.user.id}`} className="text-coral-600 hover:underline">
                  Open account
                </Link>
              </Field>
            </dl>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="font-semibold">Vehicle &amp; payout</CardTitle>
          </CardHeader>
          <CardContent>
            <dl className="grid grid-cols-2 gap-4">
              <Field label="Vehicle">{vehicleLabel(d.vehicleKind)}</Field>
              <Field label="Plate">
                <PlateBadge plate={d.plate} />
              </Field>
              <Field label="Model">{d.vehicleModel}</Field>
              <Field label="Colour">{d.vehicleColor || "–"}</Field>
              <Field label="UPI ID" className="col-span-2">
                <span className="font-mono text-[13px]">{d.upiId}</span>
              </Field>
            </dl>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="font-semibold">Performance</CardTitle>
          </CardHeader>
          <CardContent>
            <dl className="grid grid-cols-2 gap-4">
              <Field label="Rating">
                <span className="inline-flex items-center gap-1 font-heading text-xl font-semibold">
                  <StarIcon className="size-4 fill-warning text-warning" /> {d.rating.toFixed(1)}
                </span>
              </Field>
              <Field label="Trips completed">
                <span className="font-heading text-xl font-semibold">{d.ridesCount}</span>
              </Field>
              <Field label="KYC">
                <KycProgress verified={kyc.verified} total={kyc.total} />
              </Field>
              <Field label="Current plan">
                {d.subscriptions[0] ? (
                  <span className="flex items-center gap-2">
                    <StatusBadge status={d.subscriptions[0].status} /> {humanize(d.subscriptions[0].plan.period)}
                  </span>
                ) : (
                  "No plan"
                )}
              </Field>
            </dl>
          </CardContent>
        </Card>
      </div>

      <Card className="mt-4 gap-0 pb-0">
        <CardHeader className="border-b">
          <CardTitle className="font-semibold">KYC documents</CardTitle>
          <CardDescription>
            {kyc.verified} of {kyc.total} verified. All five verified approves the driver; any rejection marks the driver
            rejected.
          </CardDescription>
        </CardHeader>
        <ul className="divide-y">
          {docs.map((doc) => (
            <li key={doc.type} className="flex flex-col gap-3 px-4 py-3.5 sm:flex-row sm:items-center sm:justify-between">
              <div className="flex min-w-0 items-start gap-3">
                <span className="mt-0.5 flex size-9 shrink-0 items-center justify-center rounded-lg bg-muted text-navy-700">
                  <FileTextIcon className="size-4" aria-hidden />
                </span>
                <div className="min-w-0">
                  <p className="flex flex-wrap items-center gap-2 text-sm font-medium text-navy-900">
                    {docLabel(doc.type)} <StatusBadge status={doc.status} />
                  </p>
                  <p className="mt-0.5 text-xs text-muted-foreground">
                    Updated {formatDateTime(doc.updatedAt)}
                    {doc.fileUrl && (
                      <>
                        {" · "}
                        <a
                          href={docFileHref(doc.fileUrl)}
                          target="_blank"
                          rel="noreferrer noopener"
                          className="inline-flex items-center gap-0.5 text-coral-600 hover:underline"
                        >
                          View file <ExternalLinkIcon className="size-3" />
                        </a>
                      </>
                    )}
                  </p>
                  {doc.status === "REJECTED" && doc.rejectReason && (
                    <p className="mt-1 text-xs text-error">Reason: {doc.rejectReason}</p>
                  )}
                </div>
              </div>
              <DocumentActions driverId={d.id} type={doc.type} label={docLabel(doc.type)} status={doc.status} />
            </li>
          ))}
        </ul>
      </Card>

      <div className="mt-4 grid gap-4 xl:grid-cols-2">
        <Card className="gap-0 pb-0">
          <CardHeader className="border-b">
            <CardTitle className="font-semibold">Subscriptions</CardTitle>
            <CardDescription>Daily, weekly or monthly plans. Rido takes no commission on fares.</CardDescription>
          </CardHeader>
          {d.subscriptions.length === 0 ? (
            <EmptyState icon={WalletCardsIcon} title="No subscriptions" description="The driver hasn't started a plan yet." />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="pl-4">Plan</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Period</TableHead>
                  <TableHead className="pr-4 text-right">Price</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {d.subscriptions.map((s) => (
                  <TableRow key={s.id}>
                    <TableCell className="pl-4">
                      {vehicleLabel(s.plan.vehicleKind)} · {humanize(s.plan.period)}
                      <span className="block text-xs text-muted-foreground">
                        {s.autopay ? "UPI Autopay" : "Manual"}
                        {s.upiApp ? ` · ${s.upiApp}` : ""}
                      </span>
                    </TableCell>
                    <TableCell>
                      <StatusBadge status={s.status} />
                    </TableCell>
                    <TableCell className="text-navy-700">
                      {formatDate(s.startsAt)} – {formatDate(s.endsAt)}
                    </TableCell>
                    <TableCell className="pr-4 text-right tabular-nums">{formatInr(s.plan.price)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </Card>

        <Card className="gap-0 pb-0">
          <CardHeader className="border-b">
            <CardTitle className="font-semibold">Payments</CardTitle>
            <CardDescription>Plan payments collected from this driver.</CardDescription>
          </CardHeader>
          {payments.length === 0 ? (
            <EmptyState icon={WalletCardsIcon} title="No payments yet" description="Payments appear after the free trial ends." />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="pl-4">Date</TableHead>
                  <TableHead>Plan</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="pr-4 text-right">Amount</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {payments.map((p) => (
                  <TableRow key={p.id}>
                    <TableCell className="pl-4">
                      {formatDateTime(p.createdAt)}
                      {p.providerRef && <span className="block font-mono text-xs text-muted-foreground">{p.providerRef}</span>}
                    </TableCell>
                    <TableCell>{humanize(p.plan.period)}</TableCell>
                    <TableCell>
                      <StatusBadge status={p.status} />
                    </TableCell>
                    <TableCell className="pr-4 text-right tabular-nums">{formatInr(p.amount)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </Card>
      </div>

      <Card className="mt-4 gap-0 pb-0">
        <CardHeader className="border-b">
          <CardTitle className="font-semibold">Recent trips</CardTitle>
          <CardDescription>Last 20 rides and deliveries.</CardDescription>
        </CardHeader>
        {d.trips.length === 0 ? (
          <EmptyState icon={RouteIcon} title="No trips yet" />
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="pl-4">Trip</TableHead>
                <TableHead>When</TableHead>
                <TableHead>Route</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="pr-4 text-right">Fare</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {d.trips.map((t) => (
                <TableRow key={t.id} className="relative">
                  <TableCell className="pl-4">
                    <Link href={`/trips/${t.id}`} className="font-mono text-xs font-medium text-navy-900 after:absolute after:inset-0 hover:text-coral-600">
                      {shortId(t.id)}
                    </Link>
                    <span className="block text-xs text-muted-foreground">{humanize(t.kind)}</span>
                  </TableCell>
                  <TableCell className="text-navy-700">{formatDateTime(t.createdAt)}</TableCell>
                  <TableCell>
                    <TripRouteCell pickup={t.pickupName} drop={t.dropName} />
                  </TableCell>
                  <TableCell>
                    <StatusBadge status={t.status} />
                  </TableCell>
                  <TableCell className="pr-4 text-right tabular-nums">{formatInr(t.fareTotal)}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </Card>
    </>
  );
}
