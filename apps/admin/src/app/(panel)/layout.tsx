import { Suspense } from "react";

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

export default function PanelLayout({ children }: LayoutProps<"/">) {
  return (
    <AppShell
      userMenu={
        <Suspense fallback={<Skeleton className="size-9 rounded-full" />}>
          <SessionUserMenu />
        </Suspense>
      }
      badges={{
        "/kyc": (
          <Suspense fallback={null}>
            <KycBadge />
          </Suspense>
        ),
      }}
    >
      {children}
    </AppShell>
  );
}
