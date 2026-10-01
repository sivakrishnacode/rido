import { Suspense, cache } from "react";

import { AppShell } from "@/components/layout/app-shell";
import { UserMenu } from "@/components/layout/user-menu";
import { Skeleton } from "@/components/ui/skeleton";
import { adminApi } from "@/lib/api";
import { getSessionUser } from "@/lib/session";

/** Reads the session cookie inside its own Suspense boundary so page loading.tsx skeletons still stream. */
async function SessionUserMenu() {
  const user = await getSessionUser();
  return <UserMenu name={user?.name ?? null} phone={user?.phone ?? ""} />;
}

/** Documents waiting for review, shown next to "KYC" in the sidebar. Never breaks the layout. */
async function KycBadge() {
  const total = await adminApi
    .kyc({ status: "UNDER_REVIEW", pageSize: 1 })
    .then((r) => r.total)
    .catch(() => 0);
  if (!total) return null;
  return (
    <span className="rounded-full bg-coral-600 px-1.5 py-px text-[11px] font-semibold text-white tabular-nums">
      {total > 99 ? "99+" : total}
    </span>
  );
}

/** Drivers ready to approve plus photos to review, next to "Approvals". Never breaks the layout. */
async function ApprovalsBadge() {
  const total = await adminApi
    .approvals({ stage: "ready", pageSize: 1 })
    .then((r) => r.counts.ready + r.counts.photos)
    .catch(() => 0);
  if (!total) return null;
  return (
    <span className="rounded-full bg-coral-600 px-1.5 py-px text-[11px] font-semibold text-white tabular-nums">
      {total > 99 ? "99+" : total}
    </span>
  );
}

/** One settings read per render for the badges below. */
const settingsOnce = cache(() => adminApi.settings().catch(() => null));

/** "Off" next to the plan pages while paid driver plans are switched off (the free app). */
async function PlansOffBadge() {
  const settings = await settingsOnce();
  if (!settings || settings.driverPlansEnabled) return null;
  return <span className="rounded-full bg-muted px-1.5 py-px text-[10px] font-semibold tracking-wide text-muted-foreground uppercase">Off</span>;
}

/** Open SOS alerts, shown in red next to "SOS". Never breaks the layout. */
async function SosBadge() {
  const open = await adminApi
    .sos({ status: "OPEN", pageSize: 1 })
    .then((r) => r.open)
    .catch(() => 0);
  if (!open) return null;
  return (
    <span className="animate-pulse rounded-full bg-error px-1.5 py-px text-[11px] font-semibold text-white tabular-nums">
      {open > 99 ? "99+" : open}
    </span>
  );
}

export default function PanelLayout({ children }: LayoutProps<"/">) {
  return (
    <AppShell
      userMenu={
        <Suspense fallback={<Skeleton className="size-9 rounded-full" />}>
          <SessionUserMenu />
        </Suspense>
      }
      badges={{
        "/drivers/approvals": (
          <Suspense fallback={null}>
            <ApprovalsBadge />
          </Suspense>
        ),
        "/kyc": (
          <Suspense fallback={null}>
            <KycBadge />
          </Suspense>
        ),
        "/safety": (
          <Suspense fallback={null}>
            <SosBadge />
          </Suspense>
        ),
      }}
      tags={{
        "/plans": (
          <Suspense fallback={null}>
            <PlansOffBadge />
          </Suspense>
        ),
        "/payments": (
          <Suspense fallback={null}>
            <PlansOffBadge />
          </Suspense>
        ),
      }}
    >
      {children}
    </AppShell>
  );
}
