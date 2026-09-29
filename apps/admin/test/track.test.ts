import { describe, expect, it } from "vitest";

import { shareResult, trackModel, type ShareView } from "@/lib/track";

const NOW = Date.UTC(2026, 8, 28, 11, 0); // 4:30 pm IST

const view: ShareView = {
  status: "IN_PROGRESS",
  kind: "RIDE",
  isLive: true,
  driver: { firstName: "Selvam", vehicleKind: "BIKE", vehicleModel: "TVS Jupiter", vehicleColor: "Blue", plate: "TN 37 CD 9876" },
  location: { lat: 11.015, lng: 76.968, at: NOW - 20_000 },
  pickup: { name: "Gandhipuram", lat: 11.0183, lng: 76.9725 },
  drop: { name: "Brookefields Mall", lat: 11.009, lng: 76.96 },
  etaMin: 12,
  etaTo: "drop",
  expiresAt: new Date(NOW + 3600_000).toISOString(),
};

describe("trackModel", () => {
  it("maps a running ride to the page's lines and map points", () => {
    const m = trackModel(view, NOW);
    expect(m).toMatchObject({
      title: "Tamil Taxi ride to Brookefields Mall",
      status: "On the way",
      isLive: true,
      driverLine: "Selvam · Blue TVS Jupiter (Bike)",
      plate: "TN 37 CD 9876",
      etaLine: "Arriving at the drop in about 12 min (4:42 pm)",
      freshness: "Updated 20 s ago",
      isStale: false,
      vehicle: { lat: 11.015, lng: 76.968 },
    });
    expect(m.fit).toEqual([{ lat: 11.015, lng: 76.968 }, { lat: 11.009, lng: 76.96 }]);
  });

  it("flags an old fix, and fits pickup and drop once the trip has ended", () => {
    expect(trackModel({ ...view, location: { lat: 1, lng: 2, at: NOW - 3 * 60_000 } }, NOW)).toMatchObject({
      isStale: true,
      freshness: "Location not updated for 3 min",
    });
    const ended = trackModel({ ...view, status: "COMPLETED", isLive: false, location: null, etaMin: null, etaTo: null }, NOW);
    expect(ended).toMatchObject({ status: "Arrived", vehicle: null, etaLine: null, freshness: null });
    expect(ended.fit).toEqual([view.pickup, view.drop]);
  });

  it("says who is coming before pickup, and handles parcels and missing vehicle details", () => {
    const m = trackModel(
      { ...view, kind: "PARCEL", status: "DRIVER_ASSIGNED", etaTo: "pickup", etaMin: 4, driver: { ...view.driver!, vehicleModel: "", vehicleColor: "" } },
      NOW,
    );
    expect(m.title).toBe("Tamil Taxi parcel to Brookefields Mall");
    expect(m.driverLine).toBe("Selvam · Bike");
    expect(m.etaLine).toMatch(/^Reaching the pickup in about 4 min/);
    expect(m.fit[1]).toEqual({ lat: view.pickup.lat, lng: view.pickup.lng });
  });
});

describe("shareResult", () => {
  it("maps API statuses", () => {
    expect(shareResult(200, view)).toEqual({ kind: "ok", view });
    expect(shareResult(410, {})).toEqual({ kind: "ended" });
    expect(shareResult(404, {})).toEqual({ kind: "not-found" });
    expect(shareResult(429, {}).kind).toBe("error");
    expect(shareResult(503, null).kind).toBe("error");
  });
});
