"use client";

import { Loader2Icon, SaveIcon } from "lucide-react";
import { useState, useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { humanize } from "@/lib/format";
import type { SettingsRecord } from "@/lib/types";
import { surgeExample, validateSettings, type SettingValue, type SettingsInput } from "@/lib/validation";

import { saveSettings } from "../actions";

interface FieldDef {
  readonly key: string;
  readonly label: string;
  readonly hint: string;
  readonly step?: string;
  readonly suffix?: string;
}

interface Group {
  readonly group: string;
  readonly description: string;
  readonly fields: readonly FieldDef[];
}

const GROUPS: readonly Group[] = [
  {
    group: "Pricing & surge",
    description:
      "Live surge per res-7 hexagon: ratio = bookings ÷ free drivers over the demand window; multiplier = 1 + sensitivity × (ratio − 1), smoothed across neighbouring hexes, rounded down to 0.05 and capped by the maximum.",
    fields: [
      { key: "dynamicSurgeEnabled", label: "Dynamic surge", hint: "Off = only the current multiplier and surge zones apply" },
      { key: "surgeSensitivity", label: "Sensitivity", hint: "How fast prices rise with demand (0.1 = +0.1× per extra booking per driver)", step: "0.01" },
      { key: "demandWindowMin", label: "Demand window", hint: "Minutes of bookings counted as current demand", step: "1", suffix: "min" },
      { key: "surgeMinRequests", label: "Minimum bookings", hint: "No surge in a hexagon below this many bookings", step: "1" },
      { key: "maxMultiplier", label: "Maximum multiplier", hint: "Hard cap, surge zones included", step: "0.05", suffix: "×" },
      { key: "currentMultiplier", label: "Current multiplier", hint: "Platform-wide base multiplier (\"Peak time\")", step: "0.05", suffix: "×" },
    ],
  },
  {
    group: "Dispatch & ETA",
    description: "How bookings are matched: H3 rings around the pickup, drivers ranked by ETA, bookings assigned in batches.",
    fields: [
      { key: "batchWindowMs", label: "Batch window", hint: "Bookings collected, then assigned together", step: "100", suffix: "ms" },
      { key: "useRoadEta", label: "Road ETA", hint: "Rank drivers by Google Routes ETA (cached per hex pair); off = estimate" },
      { key: "historicalEtaMinTrips", label: "Learned ETA after", hint: "Use learned hex-to-hex speeds once a pair has this many trips (0 = off)", step: "1", suffix: "trips" },
      { key: "searchRadiusKm", label: "Search radius", hint: "Around the pickup when the search starts", step: "0.5", suffix: "km" },
      { key: "maxSearchRadiusKm", label: "Maximum search radius", hint: "Widens up to this while nobody accepts", step: "0.5", suffix: "km" },
      { key: "searchExpandSeconds", label: "Widen over", hint: "Seconds from the start radius to the maximum (0 = at once)", step: "5", suffix: "s" },
      { key: "offerSeconds", label: "Offer time", hint: "Seconds each driver has to accept", step: "1", suffix: "s" },
      { key: "maxCandidates", label: "Drivers per booking", hint: "Offered one at a time before \"No drivers\"", step: "1" },
      { key: "maxReassigns", label: "Reassigns per trip", hint: "A driver cancel before pickup finds another driver this many times, then cancels the trip", step: "1" },
      { key: "arrivalRadiusM", label: "Arrived within", hint: "Farther from the pickup, the driver must give a reason to mark Arrived", step: "10", suffix: "m" },
      { key: "dropRadiusM", label: "End trip within", hint: "Farther from the drop, the driver must give a reason to end the trip", step: "10", suffix: "m" },
    ],
  },
  {
    group: "Trip timeouts",
    description:
      "Durable timers per trip. Not moving: first check after max(minimum, factor × pickup ETA); a driver who hasn't got closer is nudged, and on the second failed check the ride goes to another driver. Started trips running far too long are flagged for review, never ended automatically.",
    fields: [
      { key: "notMovingMinMin", label: "Not moving: first check after", hint: "At least this many minutes after accept", step: "1", suffix: "min" },
      { key: "notMovingEtaFactor", label: "Not moving: × pickup ETA", hint: "First check at this × the pickup ETA, if later", step: "0.1", suffix: "×" },
      { key: "notMovingMinProgressM", label: "Not moving: must get closer by", hint: "Straight-line metres towards the pickup since accepting", step: "10", suffix: "m" },
      { key: "notMovingRecheckMin", label: "Not moving: check again after", hint: "After the nudge; the second failed check reassigns", step: "1", suffix: "min" },
      { key: "noShowWaitMin", label: "No-show wait", hint: "Minutes at the pickup before the driver may cancel as \"Passenger didn't come\" (no fault)", step: "1", suffix: "min" },
      { key: "stuckTripMinMin", label: "Stuck trip after", hint: "Started trips running at least this long are flagged…", step: "10", suffix: "min" },
      { key: "stuckDurationFactor", label: "Stuck: × estimate", hint: "…or this × the estimated minutes, if longer", step: "0.5", suffix: "×" },
      { key: "pickupHardCapMin", label: "Not started: cancel after", hint: "Safety net: accepted trips not started by then are cancelled", step: "5", suffix: "min" },
    ],
  },
  {
    group: "Waiting charge",
    description:
      "After the driver marks Arrived, the first minutes are free; then every started minute until the ride starts costs the vehicle's waiting rate (Cities › Fares), up to the cap. Charged at start as its own fare line, never surged. Rides and parcels.",
    fields: [
      { key: "freeWaitMin", label: "Free waiting", hint: "Minutes after Arrived with no charge", step: "1", suffix: "min" },
      { key: "waitMaxCharge", label: "Waiting cap", hint: "Most a trip can be charged for waiting (0 = no waiting charge)", step: "5", suffix: "₹" },
    ],
  },
  {
    group: "Cancellation fee",
    description:
      "Off by default (policy not decided). On: a passenger who cancels after the driver arrived and waited the free minutes owes this fee to that driver; it is added to their next completed ride as \"Previous cancellation fee\" and that ride's driver collects it in cash. No settlement between drivers: Finance › Cancellation fees shows who it was owed to.",
    fields: [
      { key: "cancellationFeeEnabled", label: "Cancellation fee", hint: "Off = nobody is charged for cancelling" },
      { key: "cancellationFee", label: "Fee", hint: "Per late cancellation", step: "5", suffix: "₹" },
    ],
  },
  {
    group: "Driver cancellations",
    description:
      "Driver-fault cancellations ÷ assigned trips over 7 days (counting restarts after a pause). Judged from the minimum trips; from Warn at the driver gets a push and a Home banner, from Pause at they can't go online for the pause length (the repeat length if they were paused in the last 7 days). Admins can lift a pause on the driver page. Passengers are never paused.",
    fields: [
      { key: "cancelRateMinTrips", label: "Judge after", hint: "Assigned trips in the window before a rate counts", step: "1", suffix: "trips" },
      { key: "cancelRateNudge", label: "Warn at", hint: "Share cancelled (0.3 = 30 %)", step: "0.05", suffix: "×" },
      { key: "cancelRateBlock", label: "Pause at", hint: "Share cancelled (0.5 = 50 %)", step: "0.05", suffix: "×" },
      { key: "cancelBlockHours", label: "Pause length", hint: "First pause", step: "1", suffix: "h" },
      { key: "cancelBlockRepeatHours", label: "Repeat pause length", hint: "When paused in the last 7 days", step: "1", suffix: "h" },
    ],
  },
  {
    group: "Driver ranking",
    description:
      "Who is offered a trip first (still one driver at a time): road ETA × (1 + ignored weight × share of offers not accepted + cancel weight × share of accepted rides cancelled by the driver's fault), minus an idle bonus for drivers waiting long since their last trip or going online. Offers over the last 7 days; drivers with fewer offers than Judge after are neutral. The idle bonus is a share of the driver's own ETA, so nearer drivers still come first. Off = plain ETA.",
    fields: [
      { key: "rankEnabled", label: "Rank by record", hint: "Off = nearest driver (ETA) first" },
      { key: "rankWeightAccept", label: "Ignored-offer weight", hint: "0.5: never accepting = ETA × 1.5", step: "0.1", suffix: "×" },
      { key: "rankWeightCancel", label: "Cancel weight", hint: "1.0: cancelling every ride = ETA × 2", step: "0.1", suffix: "×" },
      { key: "rankIdleMaxBoost", label: "Idle bonus", hint: "Most taken off the ETA (0.15 = 15 %)", step: "0.05", suffix: "×" },
      { key: "rankIdleFullMin", label: "Full idle bonus after", hint: "Minutes waiting", step: "1", suffix: "min" },
      { key: "rankMinOffers", label: "Judge after", hint: "Offers in 7 days before the record counts", step: "1", suffix: "offers" },
    ],
  },
  {
    group: "Driver plans",
    description: "Off = Rido is free: drivers see no plans and can always go online. Trial and grace apply to new subscriptions when plans are on.",
    fields: [
      { key: "driverPlansEnabled", label: "Paid driver plans", hint: "Off = free app, no subscription" },
      { key: "trialDays", label: "Free trial", hint: "Days for new drivers", step: "1", suffix: "days" },
      { key: "graceDays", label: "Grace period", hint: "Days a lapsed plan can still go online", step: "1", suffix: "days" },
    ],
  },
  {
    group: "Contribute",
    description: "The Contribute page in both apps: a UPI pay button and QR code, and the monthly running cost with its breakdown.",
    fields: [
      { key: "contributeUpiId", label: "UPI ID", hint: "Receives contributions, e.g. name@okaxis (empty = no pay button)" },
      { key: "contributePayeeName", label: "Payee name", hint: "Shown in the UPI app" },
      { key: "costServersInr", label: "Servers & database", hint: "Per month; the apps show the total and this breakdown", step: "100", suffix: "₹" },
      { key: "costMapsInr", label: "Maps", hint: "Google Maps per month", step: "100", suffix: "₹" },
      { key: "costSmsInr", label: "SMS (OTP)", hint: "Per month", step: "100", suffix: "₹" },
      { key: "costOtherInr", label: "Other", hint: "Domain, Play Store, tools… per month (all 0 = cost hidden)", step: "100", suffix: "₹" },
      { key: "contributeNote", label: "Message", hint: "Shown at the top of the page" },
    ],
  },
  {
    group: "Support",
    description: "Shown on the Help screens in both apps.",
    fields: [{ key: "supportPhone", label: "Support phone", hint: "Include the country code" }],
  },
];

const KNOWN = new Set(GROUPS.flatMap((g) => g.fields.map((f) => f.key)));

type Draft = Record<string, string | boolean>;

function toDraft(s: Record<string, SettingValue>): Draft {
  return Object.fromEntries(Object.entries(s).map(([k, v]) => [k, typeof v === "boolean" ? v : String(v)]));
}

/** Converts the draft back using each key's type in the API response. */
function fromDraft(d: Draft, types: Record<string, SettingValue>): SettingsInput {
  return Object.fromEntries(
    Object.entries(d).map(([k, v]) => {
      const t = typeof types[k];
      if (t === "boolean") return [k, v === true];
      if (t === "number") return [k, String(v).trim() === "" ? Number.NaN : Number(v)];
      return [k, String(v).trim()];
    }),
  ) as SettingsInput;
}

/**
 * Form over GET/PUT /admin/settings. Every key the API returns is rendered: known ones in their groups,
 * anything newer in "Other", so new settings never go missing. Only changed keys are sent.
 */
export function SettingsForm({ initial }: { initial: SettingsRecord }) {
  const types = initial as Record<string, SettingValue>;
  const [draft, setDraft] = useState<Draft>(() => toDraft(types));
  const [saved, setSaved] = useState<Draft>(() => toDraft(types));
  const [isPending, startTransition] = useTransition();
  const parsed = fromDraft(draft, types);
  const errors = validateSettings(parsed);
  const hasErrors = Object.keys(errors).length > 0;
  const changed = Object.keys(draft).filter((k) => draft[k] !== saved[k]);

  const other: Group | null = (() => {
    const keys = Object.keys(types).filter((k) => !KNOWN.has(k));
    return keys.length
      ? { group: "Other", description: "Settings added in newer API versions.", fields: keys.map((k) => ({ key: k, label: humanize(k.replace(/([a-z])([A-Z])/g, "$1_$2")), hint: k })) }
      : null;
  })();
  const groups = [...GROUPS.map((g) => ({ ...g, fields: g.fields.filter((f) => f.key in types) })), ...(other ? [other] : [])].filter((g) => g.fields.length);

  const sens = Number(draft.surgeSensitivity);
  const cap = Number(draft.maxMultiplier);
  const example = Number.isFinite(sens) && Number.isFinite(cap) ? surgeExample(3, sens, cap) : null;

  return (
    <form
      noValidate
      onSubmit={(e) => {
        e.preventDefault();
        if (hasErrors || changed.length === 0) return;
        const patch = Object.fromEntries(changed.map((k) => [k, parsed[k]])) as SettingsInput;
        startTransition(async () => {
          const res = await saveSettings(patch);
          if (res.ok) {
            setSaved(draft);
            toast.success(res.message);
          } else toast.error(res.error);
        });
      }}
      className="grid gap-4 lg:grid-cols-2"
    >
      {groups.map((g) => (
        <Card key={g.group} className={g.group === "Pricing & surge" || g.group === "Dispatch & ETA" ? "lg:row-span-1" : undefined}>
          <CardHeader>
            <CardTitle className="font-semibold">{g.group}</CardTitle>
            <CardDescription>{g.description}</CardDescription>
            {g.group === "Pricing & surge" && example !== null && (
              <p className="mt-1 rounded-md bg-coral-50 px-2.5 py-1.5 text-xs text-coral-700">
                Example: 6 bookings, 2 free drivers → ratio 3 → 1 + {Number.isFinite(sens) ? sens : "?"} × 2 = <b>{example.toFixed(2)}×</b>
                {draft.dynamicSurgeEnabled === false ? " (dynamic surge is off)" : ""}
              </p>
            )}
          </CardHeader>
          <CardContent className="grid gap-4 sm:grid-cols-2">
            {g.fields.map((f) => {
              const error = errors[f.key];
              const value = draft[f.key];
              if (typeof types[f.key] === "boolean") {
                return (
                  <label key={f.key} className="flex items-start justify-between gap-3 rounded-lg border p-3 sm:col-span-2">
                    <span>
                      <span className="block text-sm font-medium text-navy-900">{f.label}</span>
                      <span className="block text-xs text-muted-foreground">{f.hint}</span>
                    </span>
                    <Switch checked={value === true} onCheckedChange={(v) => setDraft((d) => ({ ...d, [f.key]: v }))} aria-label={f.label} />
                  </label>
                );
              }
              const isNumber = typeof types[f.key] === "number";
              return (
                <div key={f.key} className="grid content-start gap-1.5">
                  <Label htmlFor={f.key}>{f.label}</Label>
                  <div className="relative">
                    <Input
                      id={f.key}
                      type={isNumber ? "number" : f.key === "supportPhone" ? "tel" : "text"}
                      inputMode={isNumber ? "decimal" : undefined}
                      step={f.step}
                      value={String(value ?? "")}
                      onChange={(e) => setDraft((d) => ({ ...d, [f.key]: e.target.value }))}
                      aria-invalid={!!error}
                      aria-describedby={`${f.key}-hint`}
                      className={f.suffix ? "pr-14" : undefined}
                    />
                    {f.suffix && (
                      <span className="pointer-events-none absolute top-1/2 right-3 -translate-y-1/2 text-xs text-muted-foreground">{f.suffix}</span>
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
            {hasErrors ? "Fix the highlighted fields to save." : changed.length ? `${changed.length} unsaved change${changed.length > 1 ? "s" : ""}.` : "All changes saved."}
          </p>
          <Button type="submit" disabled={changed.length === 0 || hasErrors || isPending}>
            {isPending ? <Loader2Icon className="animate-spin" /> : <SaveIcon />} Save settings
          </Button>
        </CardFooter>
      </Card>
    </form>
  );
}
