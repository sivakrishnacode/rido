"use client";

import { Loader2Icon, RotateCcwIcon, SaveIcon } from "lucide-react";
import { useState, useTransition } from "react";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Separator } from "@/components/ui/separator";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { formatInr, vehicleLabel } from "@/lib/format";
import type { CityFare, VehicleKind } from "@/lib/types";
import { previewFare } from "@/lib/validation";

import { resetCityFare, setCityFare } from "../../actions";

type Row = { base: string; perKm: string; perMin: string; minFare: string };

function toRow(f: CityFare): Row {
  return { base: String(f.base), perKm: String(f.perKm), perMin: String(f.perMin), minFare: String(f.minFare) };
}

function parseRow(r: Row) {
  return { base: Number(r.base), perKm: Number(r.perKm), perMin: Number(r.perMin), minFare: Number(r.minFare) };
}

function rowErrors(r: Row): string | null {
  const v = parseRow(r);
  if (r.base === "" || !Number.isInteger(v.base) || v.base < 0 || v.base > 10_000) return "Base: whole ₹0–10,000";
  if (r.perKm === "" || !(v.perKm >= 0 && v.perKm <= 500)) return "Per km: ₹0–500";
  if (r.perMin === "" || !(v.perMin >= 0 && v.perMin <= 100)) return "Per min: ₹0–100";
  if (r.minFare === "" || !Number.isInteger(v.minFare) || v.minFare < 0 || v.minFare > 20_000) return "Min fare: whole ₹0–20,000";
  return null;
}

function FareRow({ cityId, fare, row, onChange }: { cityId: string; fare: CityFare; row: Row; onChange: (r: Row) => void }) {
  const [isPending, startTransition] = useTransition();
  const error = rowErrors(row);
  const isDirty = JSON.stringify(row) !== JSON.stringify(toRow(fare));
  const cell = (key: keyof Row, step: string, label: string) => (
    <Input
      type="number"
      step={step}
      min="0"
      value={row[key]}
      aria-label={`${vehicleLabel(fare.vehicleKind)} ${label}`}
      onChange={(e) => onChange({ ...row, [key]: e.target.value })}
      className="h-8 w-24 text-right tabular-nums"
    />
  );

  return (
    <TableRow>
      <TableCell className="pl-4">
        <span className="font-medium text-navy-900">{vehicleLabel(fare.vehicleKind)}</span>
        <span className="mt-0.5 block">
          {fare.isDefault ? <Badge variant="outline">Default</Badge> : <Badge className="bg-coral-50 text-coral-700">City rate</Badge>}
        </span>
      </TableCell>
      <TableCell>{cell("base", "1", "base fare")}</TableCell>
      <TableCell>{cell("perKm", "0.5", "per km")}</TableCell>
      <TableCell>{cell("perMin", "0.05", "per minute")}</TableCell>
      <TableCell>{cell("minFare", "1", "minimum fare")}</TableCell>
      <TableCell className="pr-4">
        <div className="flex items-center justify-end gap-1">
          {error && isDirty && <span className="mr-1 text-xs text-error">{error}</span>}
          <Button
            size="sm"
            disabled={!isDirty || !!error || isPending}
            onClick={() =>
              startTransition(async () => {
                const res = await setCityFare(cityId, fare.vehicleKind, parseRow(row));
                if (res.ok) toast.success(`${vehicleLabel(fare.vehicleKind)}: ${res.message.toLowerCase()}`);
                else toast.error(res.error);
              })
            }
          >
            {isPending ? <Loader2Icon className="animate-spin" /> : <SaveIcon />} Save
          </Button>
          <Button
            size="sm"
            variant="ghost"
            disabled={fare.isDefault || isPending}
            onClick={() =>
              startTransition(async () => {
                const res = await resetCityFare(cityId, fare.vehicleKind);
                if (res.ok) toast.success(`${vehicleLabel(fare.vehicleKind)}: ${res.message.toLowerCase()}`);
                else toast.error(res.error);
              })
            }
          >
            <RotateCcwIcon /> Reset
          </Button>
        </div>
      </TableCell>
    </TableRow>
  );
}

/** Tab c) per-city fares (override or built-in default) + a preview calculator. */
export function FaresEditor({ cityId, fares }: { cityId: string; fares: CityFare[] }) {
  const [rows, setRows] = useState<Record<string, Row>>(() => Object.fromEntries(fares.map((f) => [f.vehicleKind, toRow(f)])));
  const [kind, setKind] = useState<VehicleKind>(fares[0]?.vehicleKind ?? "BIKE");
  const [km, setKm] = useState("4.2");
  const [min, setMin] = useState("14");
  const [mult, setMult] = useState("1.1");

  const row = rows[kind];
  const quote = row && !rowErrors(row) ? previewFare(parseRow(row), Number(km) || 0, Number(min) || 0, Number(mult) || 1) : null;

  return (
    <div className="grid gap-4 xl:grid-cols-[1fr_320px]">
      <Card className="gap-0 pb-0">
        <CardHeader className="border-b">
          <CardTitle className="font-semibold">Fares</CardTitle>
          <CardDescription>
            fare = max(min fare, base + per km × km + per min × min) × multiplier, each line floored to the rupee.
          </CardDescription>
        </CardHeader>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="pl-4">Vehicle</TableHead>
              <TableHead>Base ₹</TableHead>
              <TableHead>Per km ₹</TableHead>
              <TableHead>Per min ₹</TableHead>
              <TableHead>Min fare ₹</TableHead>
              <TableHead className="pr-4" />
            </TableRow>
          </TableHeader>
          <TableBody>
            {fares.map((f) => (
              <FareRow
                key={`${f.vehicleKind}-${f.isDefault}-${f.base}-${f.perKm}-${f.perMin}-${f.minFare}`}
                cityId={cityId}
                fare={f}
                row={rows[f.vehicleKind] ?? toRow(f)}
                onChange={(r) => setRows((prev) => ({ ...prev, [f.vehicleKind]: r }))}
              />
            ))}
          </TableBody>
        </Table>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="font-semibold">Fare preview</CardTitle>
          <CardDescription>Uses the values in the table, saved or not.</CardDescription>
        </CardHeader>
        <CardContent className="grid gap-3">
          <Select value={kind} onValueChange={(v) => setKind(v as VehicleKind)}>
            <SelectTrigger className="w-full" aria-label="Vehicle">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {fares.map((f) => (
                <SelectItem key={f.vehicleKind} value={f.vehicleKind}>
                  {vehicleLabel(f.vehicleKind)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <div className="grid grid-cols-3 gap-2">
            <div className="grid gap-1.5">
              <Label htmlFor="pv-km">km</Label>
              <Input id="pv-km" type="number" step="0.1" min="0" value={km} onChange={(e) => setKm(e.target.value)} />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="pv-min">min</Label>
              <Input id="pv-min" type="number" step="1" min="0" value={min} onChange={(e) => setMin(e.target.value)} />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="pv-mult">×</Label>
              <Input id="pv-mult" type="number" step="0.05" min="1" max="1.5" value={mult} onChange={(e) => setMult(e.target.value)} />
            </div>
          </div>
          {quote ? (
            <dl className="space-y-1.5 text-sm">
              {[
                ["Base", quote.base],
                ["Distance", quote.distanceCharge],
                ["Time", quote.timeCharge],
                ["Min fare top-up", quote.minFareTopUp],
                ["Subtotal", quote.subtotal],
                [`Peak (×${quote.multiplier})`, quote.peakCharge],
              ].map(([l, v]) => (
                <div key={l as string} className="flex justify-between">
                  <dt className="text-navy-700">{l}</dt>
                  <dd className="tabular-nums">{formatInr(v as number)}</dd>
                </div>
              ))}
              <Separator />
              <div className="flex justify-between font-heading text-lg font-semibold text-navy-900">
                <dt>Total</dt>
                <dd className="tabular-nums">{formatInr(quote.total)}</dd>
              </div>
            </dl>
          ) : (
            <p className="text-sm text-error">Fix this vehicle&apos;s rates to see a preview.</p>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
