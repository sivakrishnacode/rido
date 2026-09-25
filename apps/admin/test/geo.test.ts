import { describe, expect, it } from "vitest";

import { applyCells, cellAt, circleCells, historyInit, historyPush, historyRedo, historyUndo, viewportCells } from "@/lib/hex";
import { cellsToKm2, previewFare, validateSettings } from "@/lib/validation";

describe("fare preview (same maths as the API fare engine)", () => {
  const bike = { base: 12, perKm: 5, perMin: 0.15, minFare: 25 };

  it("matches the seeded Gandhipuram → Brookefields bike trip (₹38)", () => {
    expect(previewFare(bike, 4.2, 14, 1.1)).toEqual({
      base: 12,
      distanceCharge: 21,
      timeCharge: 2,
      minFareTopUp: 0,
      subtotal: 35,
      multiplier: 1.1,
      peakCharge: 3,
      total: 38,
    });
  });

  it("tops up to the minimum fare and caps the multiplier at 1.5", () => {
    const q = previewFare(bike, 0.5, 1, 3);
    expect(q.subtotal).toBe(25);
    expect(q.minFareTopUp).toBe(25 - (12 + 2 + 0));
    expect(q.multiplier).toBe(1.5);
    expect(q.total).toBe(37);
  });
});

describe("h3 helpers", () => {
  it("fills a circle and paints/erases cells", () => {
    const centre = cellAt(11.0183, 76.9725, 8);
    const disk = circleCells(11.0183, 76.9725, 0.5, 8);
    expect(disk).toContain(centre);
    expect(disk.length).toBe(7); // 0.5 km at res 8 → k = 1 ring
    expect(applyCells(disk, [centre], "remove")).toHaveLength(6);
    expect(applyCells([centre], [centre], "add")).toEqual([centre]);
  });

  it("refuses to enumerate huge viewports", () => {
    expect(viewportCells({ south: 8, west: 74, north: 14, east: 80 }, 8)).toBeNull();
    const small = viewportCells({ south: 11.0, west: 76.95, north: 11.03, east: 76.99 }, 8);
    expect(small && small.length).toBeGreaterThan(5);
  });

  it("undoes and redoes cell edits", () => {
    let h = historyInit(["a"]);
    h = historyPush(h, ["a", "b"]);
    h = historyPush(h, ["a", "b"]); // no-op
    expect(h.past).toHaveLength(1);
    h = historyUndo(h);
    expect(h.present).toEqual(["a"]);
    h = historyRedo(h);
    expect(h.present).toEqual(["a", "b"]);
  });

  it("converts cells to km²", () => {
    expect(Math.round(cellsToKm2(1519, 8))).toBe(1120);
  });
});

describe("settings validation", () => {
  const ok = { currentMultiplier: 1.1, maxMultiplier: 1.5, searchRadiusKm: 5, offerSeconds: 15, maxCandidates: 5, trialDays: 30, graceDays: 2, batchWindowMs: 2000, useRoadEta: true, supportPhone: "+91 422 000 0000" };

  it("accepts the API defaults", () => {
    expect(validateSettings(ok)).toEqual({});
  });

  it("flags out-of-range values", () => {
    const e = validateSettings({ ...ok, currentMultiplier: 1.6, offerSeconds: 2.5, supportPhone: "x" });
    expect(Object.keys(e).sort()).toEqual(["currentMultiplier", "offerSeconds", "supportPhone"]);
    expect(validateSettings({ ...ok, currentMultiplier: 1.4, maxMultiplier: 1.2 }).currentMultiplier).toMatch(/exceed/);
  });
});
