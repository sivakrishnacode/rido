"use client";

import { CheckIcon, Loader2Icon } from "lucide-react";
import { useState, useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import { formatInr } from "@/lib/format";
import type { Plan } from "@/lib/types";
import { cn } from "@/lib/utils";

import { updatePlan } from "../actions";

/** Editable price (whole ₹) + active toggle for one plan → PATCH /admin/plans/:id. */
export function PlanCell({ plan, label, perDay }: { plan: Plan; label: string; perDay: number }) {
  const [price, setPrice] = useState(String(plan.price));
  const [saved, setSaved] = useState(plan.price);
  const [isActive, setActive] = useState(plan.isActive);
  const [isPending, startTransition] = useTransition();
  const value = Number(price);
  const isValid = price !== "" && Number.isInteger(value) && value >= 0 && value <= 100_000;
  const isDirty = isValid && value !== saved;

  function savePrice() {
    if (!isDirty) return;
    startTransition(async () => {
      const res = await updatePlan(plan.id, { price: value });
      if (res.ok) {
        setSaved(value);
        toast.success(`${label}: ${formatInr(value)}`);
      } else toast.error(res.error);
    });
  }

  function toggle(next: boolean) {
    setActive(next);
    startTransition(async () => {
      const res = await updatePlan(plan.id, { isActive: next });
      if (res.ok) toast.success(`${label} ${next ? "activated" : "deactivated"}`);
      else {
        setActive(!next);
        toast.error(res.error);
      }
    });
  }

  return (
    <div className={cn("rounded-lg border p-3 transition-opacity", !isActive && "bg-muted/50 opacity-70")}>
      <div className="mb-2 flex items-center justify-between">
        <span className="text-xs font-medium text-muted-foreground uppercase">{label}</span>
        <Switch checked={isActive} onCheckedChange={toggle} disabled={isPending} aria-label={`${label} active`} />
      </div>
      <form
        className="flex items-center gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          savePrice();
        }}
      >
        <div className="relative flex-1">
          <span className="pointer-events-none absolute top-1/2 left-2.5 -translate-y-1/2 text-sm text-muted-foreground">₹</span>
          <Input
            inputMode="numeric"
            value={price}
            onChange={(e) => setPrice(e.target.value.replace(/\D/g, "").slice(0, 6))}
            onBlur={savePrice}
            aria-label={`${label} price in rupees`}
            aria-invalid={!isValid}
            className="h-9 bg-card pl-6 font-heading text-base font-semibold tabular-nums"
          />
        </div>
        <Button type="submit" size="icon" variant={isDirty ? "default" : "ghost"} disabled={!isDirty || isPending} aria-label="Save price">
          {isPending ? <Loader2Icon className="animate-spin" /> : <CheckIcon />}
        </Button>
      </form>
      <p className="mt-1.5 text-xs text-muted-foreground">
        {isValid && perDay > 1 ? `≈ ${formatInr(Math.round(value / perDay))}/day` : isValid ? "per day" : "Whole rupees, up to ₹1,00,000"}
      </p>
    </div>
  );
}
