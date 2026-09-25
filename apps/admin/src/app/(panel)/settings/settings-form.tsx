"use client";

import { Loader2Icon, SaveIcon } from "lucide-react";
import { useState, useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import type { Settings } from "@/lib/types";
import { validateSettings } from "@/lib/validation";

import { saveSettings } from "../actions";

type NumberKey = { [K in keyof Settings]: Settings[K] extends number ? K : never }[keyof Settings];

type FieldDef =
  | { kind: "number"; key: NumberKey; label: string; hint: string; step: string; suffix?: string }
  | { kind: "text"; key: "supportPhone"; label: string; hint: string }
  | { kind: "switch"; key: "useRoadEta"; label: string; hint: string };

const GROUPS: { group: string; description: string; fields: FieldDef[] }[] = [
  {
    group: "Pricing",
    description: "Fares follow the same engine as the apps; multipliers are capped at 1.5×.",
    fields: [
      { kind: "number", key: "currentMultiplier", label: "Current multiplier", hint: "Platform-wide demand multiplier (\"Peak time\")", step: "0.05", suffix: "×" },
      { kind: "number", key: "maxMultiplier", label: "Maximum multiplier", hint: "Hard cap, surge zones included", step: "0.05", suffix: "×" },
    ],
  },
  {
    group: "Dispatch",
    description: "How bookings are matched to drivers (H3 rings around the pickup, ranked by ETA).",
    fields: [
      { kind: "number", key: "searchRadiusKm", label: "Search radius", hint: "Around the pickup", step: "0.5", suffix: "km" },
      { kind: "number", key: "offerSeconds", label: "Offer time", hint: "Seconds each driver has to accept", step: "1", suffix: "s" },
      { kind: "number", key: "maxCandidates", label: "Drivers per booking", hint: "Offered one at a time before \"No drivers\"", step: "1" },
      { kind: "number", key: "batchWindowMs", label: "Batch window", hint: "Bookings collected, then assigned together", step: "100", suffix: "ms" },
      { kind: "switch", key: "useRoadEta", label: "Road ETA", hint: "Rank drivers by Google Routes ETA (cached per hex pair); off = estimate" },
    ],
  },
  {
    group: "Driver plans",
    description: "Applies to new subscriptions.",
    fields: [
      { kind: "number", key: "trialDays", label: "Free trial", hint: "Days for new drivers", step: "1", suffix: "days" },
      { kind: "number", key: "graceDays", label: "Grace period", hint: "Days a lapsed plan can still go online", step: "1", suffix: "days" },
    ],
  },
  {
    group: "Support",
    description: "Shown on the Help screens in both apps.",
    fields: [{ kind: "text", key: "supportPhone", label: "Support phone", hint: "Include the country code" }],
  },
];

const NUMBER_KEYS = GROUPS.flatMap((g) => g.fields).filter((f) => f.kind === "number").map((f) => f.key as NumberKey);

type Draft = Record<NumberKey, string> & { supportPhone: string; useRoadEta: boolean };

function toDraft(s: Settings): Draft {
  return {
    ...(Object.fromEntries(NUMBER_KEYS.map((k) => [k, String(s[k])])) as Record<NumberKey, string>),
    supportPhone: s.supportPhone,
    useRoadEta: s.useRoadEta,
  };
}

function fromDraft(d: Draft): Settings {
  return {
    ...(Object.fromEntries(NUMBER_KEYS.map((k) => [k, d[k].trim() === "" ? Number.NaN : Number(d[k])])) as Record<NumberKey, number>),
    supportPhone: d.supportPhone.trim(),
    useRoadEta: d.useRoadEta,
  };
}

/** Form over GET/PUT /admin/settings; only the keys listed above are sent. */
export function SettingsForm({ initial }: { initial: Settings }) {
  const [draft, setDraft] = useState<Draft>(() => toDraft(initial));
  const [saved, setSaved] = useState<Draft>(() => toDraft(initial));
  const [isPending, startTransition] = useTransition();
  const parsed = fromDraft(draft);
  const errors = validateSettings(parsed);
  const hasErrors = Object.keys(errors).length > 0;
  const isDirty = JSON.stringify(draft) !== JSON.stringify(saved);

  return (
    <form
      noValidate
      onSubmit={(e) => {
        e.preventDefault();
        if (hasErrors) return;
        startTransition(async () => {
          const res = await saveSettings(parsed);
          if (res.ok) {
            setSaved(draft);
            toast.success(res.message);
          } else toast.error(res.error);
        });
      }}
      className="grid gap-4 lg:grid-cols-2"
    >
      {GROUPS.map((g) => (
        <Card key={g.group}>
          <CardHeader>
            <CardTitle className="font-semibold">{g.group}</CardTitle>
            <CardDescription>{g.description}</CardDescription>
          </CardHeader>
          <CardContent className="grid gap-4 sm:grid-cols-2">
            {g.fields.map((f) => {
              const error = errors[f.key];
              if (f.kind === "switch") {
                return (
                  <label key={f.key} className="flex items-start justify-between gap-3 rounded-lg border p-3 sm:col-span-2">
                    <span>
                      <span className="block text-sm font-medium text-navy-900">{f.label}</span>
                      <span className="block text-xs text-muted-foreground">{f.hint}</span>
                    </span>
                    <Switch checked={draft.useRoadEta} onCheckedChange={(v) => setDraft((d) => ({ ...d, useRoadEta: v }))} aria-label={f.label} />
                  </label>
                );
              }
              const suffix = f.kind === "number" ? f.suffix : undefined;
              return (
                <div key={f.key} className="grid content-start gap-1.5">
                  <Label htmlFor={f.key}>{f.label}</Label>
                  <div className="relative">
                    <Input
                      id={f.key}
                      type={f.kind === "text" ? "tel" : "number"}
                      inputMode={f.kind === "text" ? "tel" : "decimal"}
                      step={f.kind === "number" ? f.step : undefined}
                      value={draft[f.key]}
                      onChange={(e) => setDraft((d) => ({ ...d, [f.key]: e.target.value }))}
                      aria-invalid={!!error}
                      aria-describedby={`${f.key}-hint`}
                      className={suffix ? "pr-12" : undefined}
                    />
                    {suffix && (
                      <span className="pointer-events-none absolute top-1/2 right-3 -translate-y-1/2 text-xs text-muted-foreground">
                        {suffix}
                      </span>
                    )}
                  </div>
                  <p id={`${f.key}-hint`} className={error ? "text-xs text-error" : "text-xs text-muted-foreground"}>
                    {error ?? f.hint}
                  </p>
                </div>
              );
            })}
          </CardContent>
        </Card>
      ))}
      <Card className="lg:col-span-2">
        <CardFooter className="justify-between gap-3 border-t-0 bg-transparent">
          <p className="text-sm text-muted-foreground">
            {hasErrors ? "Fix the highlighted fields to save." : isDirty ? "You have unsaved changes." : "All changes saved."}
          </p>
          <Button type="submit" disabled={!isDirty || hasErrors || isPending}>
            {isPending ? <Loader2Icon className="animate-spin" /> : <SaveIcon />} Save settings
          </Button>
        </CardFooter>
      </Card>
    </form>
  );
}
