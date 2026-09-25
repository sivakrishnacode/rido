import { BadgeIndianRupeeIcon } from "lucide-react";
import type { Metadata } from "next";

import { EmptyState, PageHeader } from "@/components/common/page";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { adminApi } from "@/lib/api";
import { humanize, vehicleLabel } from "@/lib/format";
import { PLAN_PERIODS, VEHICLE_KINDS } from "@/lib/types";

import { PlanCell } from "./plan-cell";

export const metadata: Metadata = { title: "Plans" };

const DAYS = { DAILY: 1, WEEKLY: 7, MONTHLY: 30 } as const;

export default async function PlansPage() {
  const plans = await adminApi.plans();
  const kinds = VEHICLE_KINDS.filter((k) => plans.some((p) => p.vehicleKind === k));

  return (
    <>
      <PageHeader
        title="Plans"
        description="Drivers pay a flat daily, weekly or monthly plan and keep 100% of every fare. Changes apply to new purchases."
      />
      {plans.length === 0 ? (
        <Card>
          <EmptyState icon={BadgeIndianRupeeIcon} title="No plans configured" description="Run the API seed to create the price list." />
        </Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
          {kinds.map((kind) => (
            <Card key={kind} className="gap-3">
              <CardHeader>
                <CardTitle className="font-semibold">{vehicleLabel(kind)}</CardTitle>
              </CardHeader>
              <CardContent className="grid gap-2">
                {PLAN_PERIODS.map((period) => {
                  const plan = plans.find((p) => p.vehicleKind === kind && p.period === period);
                  return plan ? (
                    <PlanCell key={plan.id} plan={plan} label={humanize(period)} perDay={DAYS[period]} />
                  ) : (
                    <p key={period} className="rounded-lg border border-dashed p-3 text-xs text-muted-foreground">
                      No {period.toLowerCase()} plan
                    </p>
                  );
                })}
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </>
  );
}
