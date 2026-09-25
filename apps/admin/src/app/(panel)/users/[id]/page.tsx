import { ArrowLeftIcon, BanIcon, HeartHandshakeIcon, LifeBuoyIcon, MapPinIcon, RouteIcon } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";

import { EmptyState, Field, PageHeader } from "@/components/common/page";
import { PlateBadge, StatusBadge } from "@/components/common/status";
import { TripRouteCell } from "@/components/common/trip-bits";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { adminApi } from "@/lib/api";
import { displayName, formatDate, formatDateTime, formatInr, formatPhone, humanize, initials, kycProgress, shortId, vehicleLabel } from "@/lib/format";
import { getSessionUser } from "@/lib/session";

import { BlockControl, RoleControl } from "./user-actions";

export async function generateMetadata({ params }: PageProps<"/users/[id]">): Promise<Metadata> {
  const { id } = await params;
  return { title: `User ${shortId(id)}` };
}

export default async function UserPage({ params }: PageProps<"/users/[id]">) {
  const { id } = await params;
  const [u, me] = await Promise.all([adminApi.user(id), getSessionUser()]);
  const name = displayName(u);
  const isSelf = !!me && me.phone === u.phone;

  return (
    <>
      <Link href="/users" className="mb-3 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeftIcon className="size-4" /> Users
      </Link>
      <PageHeader
        title={
          <span className="flex items-center gap-3">
            <Avatar className="size-12">
              <AvatarFallback className="bg-coral-50 text-base font-semibold text-coral-600">{initials(u.name)}</AvatarFallback>
            </Avatar>
            <span className="min-w-0">
              <span className="block truncate">{name}</span>
              <span className="mt-1 flex flex-wrap items-center gap-2 font-sans text-sm font-normal text-muted-foreground">
                <Badge variant="outline">{humanize(u.role)}</Badge>
                {u.isBlocked && (
                  <Badge variant="secondary" className="bg-error-tint text-error">
                    <BanIcon /> Blocked
                  </Badge>
                )}
                <span>{formatPhone(u.phone)}</span>
                <span>· joined {formatDate(u.createdAt)}</span>
              </span>
            </span>
          </span>
        }
        actions={
          isSelf ? (
            <p className="text-sm text-muted-foreground">This is your account.</p>
          ) : (
            <>
              <RoleControl userId={u.id} role={u.role} name={name} />
              <BlockControl userId={u.id} isBlocked={!!u.isBlocked} name={name} />
            </>
          )
        }
      />

      {u.isBlocked && (
        <p className="mb-4 rounded-lg bg-error-tint px-4 py-3 text-sm text-error">
          Blocked{u.blockedReason ? `: ${u.blockedReason}` : ""}
        </p>
      )}

      <div className="grid gap-4 lg:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle className="font-semibold">Profile</CardTitle>
          </CardHeader>
          <CardContent>
            <dl className="grid grid-cols-2 gap-4">
              <Field label="Name">{u.name ?? "–"}</Field>
              <Field label="Phone">{formatPhone(u.phone)}</Field>
              <Field label="Email">{u.email ?? "–"}</Field>
              <Field label="Gender">{humanize(u.gender)}</Field>
              <Field label="Women drivers">{u.preferWomenDriver ? "Preferred" : "No preference"}</Field>
              <Field label="Auto-share trips">{u.autoShareTrips ? "On" : "Off"}</Field>
            </dl>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="font-semibold">Driver profile</CardTitle>
          </CardHeader>
          <CardContent>
            {u.driver ? (
              <dl className="grid grid-cols-2 gap-4">
                <Field label="Status">
                  <StatusBadge status={u.driver.status} />
                </Field>
                <Field label="Vehicle">{vehicleLabel(u.driver.vehicleKind)}</Field>
                <Field label="Plate">
                  <PlateBadge plate={u.driver.plate} />
                </Field>
                <Field label="KYC">
                  {kycProgress(u.driver.documents).verified}/5 verified
                </Field>
                <div className="col-span-2">
                  <Button asChild variant="outline" size="sm">
                    <Link href={`/drivers/${u.driver.id}`}>Open driver profile</Link>
                  </Button>
                </div>
              </dl>
            ) : (
              <p className="text-sm text-muted-foreground">Not registered as a driver.</p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 font-semibold">
              <HeartHandshakeIcon className="size-4 text-coral-600" /> Emergency contacts
            </CardTitle>
          </CardHeader>
          <CardContent>
            {u.emergencyContacts.length === 0 ? (
              <p className="text-sm text-muted-foreground">None added.</p>
            ) : (
              <ul className="space-y-2">
                {u.emergencyContacts.map((c) => (
                  <li key={c.id} className="text-sm">
                    <span className="font-medium text-navy-900">{c.name}</span>{" "}
                    <span className="text-muted-foreground">({c.relation})</span>
                    <span className="block text-xs text-navy-700">{c.phone}</span>
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>
      </div>

      <Card className="mt-4">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 font-semibold">
            <MapPinIcon className="size-4 text-coral-600" /> Saved places
          </CardTitle>
        </CardHeader>
        <CardContent>
          {u.savedPlaces.length === 0 ? (
            <p className="text-sm text-muted-foreground">No saved places.</p>
          ) : (
            <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {u.savedPlaces.map((p) => (
                <li key={p.id} className="rounded-lg border p-3 text-sm">
                  <span className="flex items-center gap-2 font-medium text-navy-900">
                    {p.label} <Badge variant="outline">{humanize(p.kind)}</Badge>
                  </span>
                  <span className="block text-navy-700">{p.name}</span>
                  <span className="block text-xs text-muted-foreground">{p.address}</span>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>

      <div className="mt-4 grid gap-4 xl:grid-cols-5">
        <Card className="gap-0 pb-0 xl:col-span-3">
          <CardHeader className="border-b">
            <CardTitle className="flex items-center gap-2 font-semibold">
              <RouteIcon className="size-4 text-coral-600" /> Recent trips
            </CardTitle>
            <CardDescription>Trips booked as a passenger (last 20).</CardDescription>
          </CardHeader>
          {u.trips.length === 0 ? (
            <EmptyState icon={RouteIcon} title="No trips yet" />
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="pl-4">Trip</TableHead>
                  <TableHead>Route</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="pr-4 text-right">Fare</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {u.trips.map((t) => (
                  <TableRow key={t.id} className="relative">
                    <TableCell className="pl-4">
                      <Link href={`/trips/${t.id}`} className="font-mono text-xs font-medium after:absolute after:inset-0 hover:text-coral-600">
                        #{shortId(t.id)}
                      </Link>
                      <span className="block text-xs text-muted-foreground">{formatDateTime(t.createdAt)}</span>
                    </TableCell>
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
        <Card className="gap-0 pb-0 xl:col-span-2">
          <CardHeader className="border-b">
            <CardTitle className="flex items-center gap-2 font-semibold">
              <LifeBuoyIcon className="size-4 text-coral-600" /> Tickets
            </CardTitle>
          </CardHeader>
          {u.tickets.length === 0 ? (
            <EmptyState icon={LifeBuoyIcon} title="No tickets" />
          ) : (
            <ul className="divide-y">
              {u.tickets.map((t) => (
                <li key={t.id} className="px-4 py-3">
                  <p className="flex items-center justify-between gap-2 text-sm font-medium text-navy-900">
                    {t.topic} <StatusBadge status={t.status} />
                  </p>
                  <p className="line-clamp-2 text-sm text-navy-700">{t.description}</p>
                  <p className="text-xs text-muted-foreground">{formatDateTime(t.createdAt)}</p>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </>
  );
}
