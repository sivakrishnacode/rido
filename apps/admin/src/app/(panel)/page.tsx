import {
  BadgeIndianRupeeIcon,
  BanIcon,
  CarIcon,
  FileSearchIcon,
  HexagonIcon,
  ClipboardCheckIcon,
  IdCardIcon,
  LifeBuoyIcon,
  RadioIcon,
  ReceiptIndianRupeeIcon,
  RouteIcon,
  UsersIcon,
  WalletCardsIcon,
  type LucideIcon,
} from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";

import { EmptyState, PageHeader } from "@/components/common/page";
import { KycProgress, PlateBadge } from "@/components/common/status";
import { Button } from "@/components/ui/button";
import { Card, CardAction, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { adminApi } from "@/lib/api";
import { displayName, formatCount, formatDate, formatInr, kycProgress, vehicleLabel } from "@/lib/format";
import { cn } from "@/lib/utils";

import { MiniLiveMap } from "./mini-live-map";
import { TripsChart } from "./trips-chart";

export const metadata: Metadata = { title: "Dashboard" };

function Kpi({
  label,
  value,
  hint,
  icon: Icon,
  href,
  isHighlighted = false,
}: {
  label: string;
  value: string;
  hint?: string;
  icon: LucideIcon;
  href?: string;
  isHighlighted?: boolean;
}) {
  const body = (
    <Card className={cn("h-full gap-2 transition-shadow", href && "hover:shadow-md", isHighlighted && "ring-coral-500/40")}>
      <CardHeader className="flex items-center justify-between gap-2">
        <CardDescription className="font-medium">{label}</CardDescription>
        <span
          className={cn(
            "flex size-8 items-center justify-center rounded-lg",
            isHighlighted ? "bg-coral-600 text-white" : "bg-coral-50 text-coral-600",
          )}
        >
          <Icon className="size-4" aria-hidden />
        </span>
      </CardHeader>
      <CardContent>
        <p className="font-heading text-2xl font-semibold tabular-nums text-navy-900">{value}</p>
        {hint && <p className="mt-0.5 text-xs text-muted-foreground">{hint}</p>}
      </CardContent>
    </Card>
  );
  return href ? (
    <Link href={href} className="rounded-xl focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none">
      {body}
    </Link>
  ) : (
    body
  );
}

export default async function DashboardPage() {
  const [stats, pending, kyc, blocked, cities, live] = await Promise.all([
    adminApi.stats(),
    adminApi.drivers({ status: "PENDING", pageSize: 5 }),
    adminApi.kyc({ status: "UNDER_REVIEW", pageSize: 1 }),
    // Optional extra: never let one KPI take the dashboard down.
    adminApi.users({ blocked: "true", pageSize: 1 }).catch(() => null),
    adminApi.cities(),
    adminApi.live(),
  ]);
  const activeCities = cities.filter((c) => c.isActive);
  const mapCenter: [number, number] = activeCities[0] ? [activeCities[0].centerLat, activeCities[0].centerLng] : [11.0168, 76.9658];
  const { drivers, trips, revenue } = stats;
  const weekTotal = stats.tripsLast7Days.reduce((a, d) => a + d.count, 0);

  return (
    <>
      <PageHeader title="Dashboard" description="Today across Rido: drivers, trips, plan revenue and support." />

      <div className="grid grid-cols-2 gap-3 sm:gap-4 md:grid-cols-3 xl:grid-cols-5">
        <Kpi
          label="Drivers"
          value={formatCount(drivers.total)}
          hint={`${formatCount(drivers.approved)} approved · ${formatCount(drivers.onHold)} on hold`}
          icon={IdCardIcon}
          href="/drivers"
        />
        <Kpi
          label="Pending KYC"
          value={formatCount(drivers.pending)}
          hint={drivers.rejected ? `${formatCount(drivers.rejected)} rejected` : "Waiting for review"}
          icon={ClipboardCheckIcon}
          href="/drivers?status=PENDING"
          isHighlighted={drivers.pending > 0}
        />
        <Kpi label="Online now" value={formatCount(drivers.online)} hint="Drivers taking jobs" icon={RadioIcon} />
        <Kpi label="Passengers" value={formatCount(stats.passengers)} hint="Registered riders" icon={UsersIcon} href="/passengers" />
        <Kpi
          label="Trips today"
          value={formatCount(trips.today)}
          hint={`${formatCount(trips.completedToday)} completed · ${formatCount(trips.cancelledToday)} cancelled`}
          icon={RouteIcon}
          href="/trips"
        />
        <Kpi label="Active trips" value={formatCount(trips.active)} hint="Searching or on the road" icon={CarIcon} href="/trips" />
        <Kpi
          label="Fares today"
          value={formatInr(trips.faresToday)}
          hint="Completed trips · 100% to drivers"
          icon={ReceiptIndianRupeeIcon}
        />
        <Kpi label="Plan revenue" value={formatInr(revenue.paidThisMonth)} hint="Paid this month" icon={BadgeIndianRupeeIcon} href="/plans" />
        <Kpi
          label="Subscriptions"
          value={formatCount(revenue.activeSubscriptions + revenue.trialSubscriptions)}
          hint={`${formatCount(revenue.activeSubscriptions)} active · ${formatCount(revenue.trialSubscriptions)} on trial`}
          icon={WalletCardsIcon}
        />
        <Kpi
          label="Open tickets"
          value={formatCount(stats.openTickets)}
          hint="Open or in progress"
          icon={LifeBuoyIcon}
          href="/support"
          isHighlighted={stats.openTickets > 0}
        />
        <Kpi
          label="KYC documents"
          value={formatCount(kyc.total)}
          hint="Waiting for review"
          icon={FileSearchIcon}
          href="/kyc"
          isHighlighted={kyc.total > 0}
        />
        <Kpi
          label="Cities"
          value={formatCount(activeCities.length)}
          hint={`${formatCount(cities.reduce((a, c) => a + c._count.zones, 0))} zones · ${formatCount(cities.length - activeCities.length)} inactive`}
          icon={HexagonIcon}
          href="/cities"
        />
        <Kpi
          label="Blocked users"
          value={blocked ? formatCount(blocked.total) : "–"}
          hint={blocked ? "Can't book or drive" : "Unavailable: API rejected ?blocked"}
          icon={BanIcon}
          href="/users?blocked=true"
        />
      </div>

      <Card className="mt-6 gap-0 overflow-hidden pb-0">
        <CardHeader className="border-b">
          <CardTitle className="font-semibold">Live now</CardTitle>
          <CardDescription>
            {formatCount(live.drivers.length)} drivers online · {formatCount(live.trips.length)} active trips
          </CardDescription>
          <CardAction>
            <Button asChild variant="ghost" size="sm">
              <Link href="/live">Open live map</Link>
            </Button>
          </CardAction>
        </CardHeader>
        <div className="h-64">
          <MiniLiveMap data={live} center={mapCenter} />
        </div>
      </Card>

      <div className="mt-6 grid gap-4 lg:grid-cols-5">
        <Card className="lg:col-span-3">
          <CardHeader>
            <CardTitle className="font-semibold">Trips, last 7 days</CardTitle>
            <CardDescription>{formatCount(weekTotal)} trips booked (rides and parcels)</CardDescription>
          </CardHeader>
          <CardContent>
            <TripsChart data={stats.tripsLast7Days} />
          </CardContent>
        </Card>

        <Card className="gap-0 lg:col-span-2">
          <CardHeader className="border-b">
            <CardTitle className="font-semibold">Pending KYC</CardTitle>
            <CardDescription>{formatCount(pending.total)} drivers waiting for review</CardDescription>
            <CardAction>
              <Button asChild variant="ghost" size="sm">
                <Link href="/drivers?status=PENDING">View all</Link>
              </Button>
            </CardAction>
          </CardHeader>
          {pending.items.length === 0 ? (
            <EmptyState icon={ClipboardCheckIcon} title="All caught up" description="No drivers are waiting for KYC review." />
          ) : (
            <ul className="divide-y">
              {pending.items.map((d) => {
                const kyc = kycProgress(d.documents);
                return (
                  <li key={d.id}>
                    <Link
                      href={`/drivers/${d.id}`}
                      className="flex items-center justify-between gap-3 px-4 py-3 transition-colors hover:bg-muted/50"
                    >
                      <span className="min-w-0">
                        <span className="block truncate text-sm font-medium text-navy-900">{displayName(d.user)}</span>
                        <span className="mt-1 flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                          {vehicleLabel(d.vehicleKind)} <PlateBadge plate={d.plate} /> · joined {formatDate(d.createdAt)}
                        </span>
                      </span>
                      <KycProgress verified={kyc.verified} total={kyc.total} />
                    </Link>
                  </li>
                );
              })}
            </ul>
          )}
        </Card>
      </div>
    </>
  );
}
