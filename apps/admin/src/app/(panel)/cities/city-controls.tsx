"use client";

import { Loader2Icon, PlusIcon } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { toast } from "sonner";

import { PointPicker } from "@/components/map/lazy";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";

import { createCity, updateCity } from "../actions";

function slugify(v: string): string {
  return v
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 40);
}

/** "Add city" → POST /admin/cities (centre by typing or clicking the map; initial hex fill = circle). */
export function AddCityButton() {
  const router = useRouter();
  const [isOpen, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [id, setId] = useState("");
  const [isIdEdited, setIdEdited] = useState(false);
  const [state, setState] = useState("Tamil Nadu");
  const [lat, setLat] = useState("");
  const [lng, setLng] = useState("");
  const [radius, setRadius] = useState("10");
  const [res, setRes] = useState("8");
  const [isPending, startTransition] = useTransition();

  const latN = Number(lat);
  const lngN = Number(lng);
  const radiusN = Number(radius);
  const isValid =
    /^[a-z0-9-]{2,40}$/.test(id) &&
    name.trim().length >= 2 &&
    state.trim().length >= 2 &&
    lat !== "" &&
    lng !== "" &&
    Math.abs(latN) <= 90 &&
    Math.abs(lngN) <= 180 &&
    radiusN >= 0 &&
    radiusN <= 60;

  return (
    <>
      <Button onClick={() => setOpen(true)}>
        <PlusIcon /> Add city
      </Button>
      <Dialog open={isOpen} onOpenChange={setOpen}>
        <DialogContent className="sm:max-w-2xl">
          <form
            className="grid gap-4"
            onSubmit={(e) => {
              e.preventDefault();
              if (!isValid) return;
              startTransition(async () => {
                const r = await createCity({
                  id,
                  name,
                  state,
                  centerLat: latN,
                  centerLng: lngN,
                  radiusKm: radiusN,
                  h3Resolution: Number(res),
                });
                if (r.ok) {
                  toast.success(r.message);
                  setOpen(false);
                  router.push(`/cities/${id}`);
                } else toast.error(r.error);
              });
            }}
          >
            <DialogHeader>
              <DialogTitle>Add a city</DialogTitle>
              <DialogDescription>
                The service area starts as hexagons within the radius around the centre. Refine it on the map afterwards.
              </DialogDescription>
            </DialogHeader>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="grid content-start gap-3">
                <div className="grid gap-1.5">
                  <Label htmlFor="city-name">Name</Label>
                  <Input
                    id="city-name"
                    value={name}
                    placeholder="Tiruppur"
                    onChange={(e) => {
                      setName(e.target.value);
                      if (!isIdEdited) setId(slugify(e.target.value));
                    }}
                  />
                </div>
                <div className="grid gap-1.5">
                  <Label htmlFor="city-id">Id (slug)</Label>
                  <Input
                    id="city-id"
                    value={id}
                    onChange={(e) => {
                      setIdEdited(true);
                      setId(slugify(e.target.value));
                    }}
                    className="font-mono"
                  />
                </div>
                <div className="grid gap-1.5">
                  <Label htmlFor="city-state">State</Label>
                  <Input id="city-state" value={state} onChange={(e) => setState(e.target.value)} />
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div className="grid gap-1.5">
                    <Label htmlFor="city-lat">Centre lat</Label>
                    <Input id="city-lat" inputMode="decimal" value={lat} onChange={(e) => setLat(e.target.value)} placeholder="11.1085" />
                  </div>
                  <div className="grid gap-1.5">
                    <Label htmlFor="city-lng">Centre lng</Label>
                    <Input id="city-lng" inputMode="decimal" value={lng} onChange={(e) => setLng(e.target.value)} placeholder="77.3411" />
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div className="grid gap-1.5">
                    <Label htmlFor="city-radius">Radius (km)</Label>
                    <Input id="city-radius" inputMode="decimal" value={radius} onChange={(e) => setRadius(e.target.value)} />
                  </div>
                  <div className="grid gap-1.5">
                    <Label>H3 resolution</Label>
                    <Select value={res} onValueChange={setRes}>
                      <SelectTrigger className="w-full" aria-label="H3 resolution">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="7">7 (≈5.2 km²)</SelectItem>
                        <SelectItem value="8">8 (≈0.74 km²)</SelectItem>
                        <SelectItem value="9">9 (≈0.11 km²)</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>
              </div>
              <div className="grid content-start gap-1.5">
                <Label>Pick the centre on the map</Label>
                <div className="h-72 overflow-hidden rounded-xl border">
                  {isOpen && (
                    <PointPicker
                      lat={lat === "" ? Number.NaN : latN}
                      lng={lng === "" ? Number.NaN : lngN}
                      onPick={(a, b) => {
                        setLat(String(a));
                        setLng(String(b));
                      }}
                    />
                  )}
                </div>
              </div>
            </div>
            <DialogFooter>
              <DialogClose asChild>
                <Button type="button" variant="outline">
                  Cancel
                </Button>
              </DialogClose>
              <Button type="submit" disabled={!isValid || isPending}>
                {isPending && <Loader2Icon className="animate-spin" />} Create city
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </>
  );
}

export function CityActiveSwitch({ id, name, isActive }: { id: string; name: string; isActive: boolean }) {
  const [checked, setChecked] = useState(isActive);
  const [isPending, startTransition] = useTransition();
  return (
    <Switch
      checked={checked}
      disabled={isPending}
      aria-label={`${name} active`}
      className="relative z-10"
      onCheckedChange={(next) => {
        setChecked(next);
        startTransition(async () => {
          const r = await updateCity(id, { isActive: next });
          if (r.ok) toast.success(r.message);
          else {
            setChecked(!next);
            toast.error(r.error);
          }
        });
      }}
    />
  );
}
