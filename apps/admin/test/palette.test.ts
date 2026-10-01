import { describe, expect, it } from "vitest";

import { paletteItems, type PalettePage } from "@/lib/palette";

const drivers: PalettePage = { href: "/drivers", label: "All drivers", group: "Drivers", searchHint: "Search drivers" };
const live: PalettePage = { href: "/live", label: "Live map", group: "Overview" };
const pages = [drivers, live, { href: "/settings", label: "Settings", group: "Platform" }];

describe("paletteItems", () => {
  it("lists every page while the box is empty", () => {
    const items = paletteItems({ q: "", current: live, fallbackSearch: drivers, pages, results: null });
    expect(items.map((i) => i.href)).toEqual(["/drivers", "/live", "/settings"]);
  });

  it("offers to search the open list page, else all drivers, then matching pages", () => {
    const onDrivers = paletteItems({ q: "set", current: drivers, fallbackSearch: drivers, pages, results: null });
    expect(onDrivers[0]).toMatchObject({ group: "Search", href: "/drivers?q=set" });
    expect(onDrivers.slice(1).map((i) => i.href)).toEqual(["/settings"]);
    expect(paletteItems({ q: "x", current: live, fallbackSearch: drivers, pages, results: null })[0].href).toBe("/drivers?q=x");
  });

  it("adds drivers, people and trips from the API", () => {
    const items = paletteItems({
      q: "selvi",
      current: live,
      fallbackSearch: drivers,
      pages,
      results: {
        drivers: [{ id: "d1", userId: "u1", plate: "TN 38 AB 1234", vehicleKind: "AUTO", status: "APPROVED", isOnline: true, user: { name: "Selvi R", phone: "+919000000002" } }],
        people: [{ id: "u2", name: null, phone: "+919000000003", role: "PASSENGER", isBlocked: true }],
        trips: [{ id: "cmabcdefgh12345678", status: "COMPLETED", kind: "RIDE", pickupName: "A", dropName: "B", fareTotal: 66, createdAt: "2026-10-01T00:00:00Z" }],
      },
    });
    expect(items.filter((i) => i.group !== "Search" && i.group !== "Pages").map((i) => [i.group, i.href, i.hint])).toEqual([
      ["Drivers", "/drivers/d1", "TN 38 AB 1234 · Auto · Approved · online"],
      ["Riders & accounts", "/users/u2", "+91 90000 00003 · Rider · blocked"],
      ["Trips", "/trips/cmabcdefgh12345678", "Completed · ₹66"],
    ]);
  });
});
