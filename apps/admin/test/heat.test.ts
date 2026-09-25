import { describe, expect, it } from "vitest";

import { HEAT_STOPS, heatColor, heatLegend, heatQuery, presetRange } from "@/lib/heat";
import { cellAt, toResolution } from "@/lib/hex";

describe("heat colour scale", () => {
  it("runs from the first to the last stop and clamps", () => {
    expect(heatColor(0).toUpperCase()).toBe(HEAT_STOPS[0]);
    expect(heatColor(1).toUpperCase()).toBe(HEAT_STOPS[HEAT_STOPS.length - 1]);
    expect(heatColor(-3)).toBe(heatColor(0));
    expect(heatColor(9)).toBe(heatColor(1));
    expect(heatColor(Number.NaN)).toBe(heatColor(0));
  });

  it("builds 5 legend bands covering 0..max", () => {
    const l = heatLegend(271);
    expect(l).toHaveLength(5);
    expect(l[0].from).toBe(0);
    expect(l[4].to).toBe(271);
    for (let i = 1; i < 5; i++) expect(l[i].from).toBe(l[i - 1].to + 1);
  });
});

describe("heat filters", () => {
  it("date presets end now; today starts at IST midnight", () => {
    const now = new Date("2026-09-25T17:00:00Z"); // 22:30 IST
    expect(presetRange("7d", now)).toEqual({ from: "2026-09-18T17:00:00.000Z", to: now.toISOString() });
    expect(presetRange("today", now).from).toBe("2026-09-24T18:30:00.000Z");
  });

  it("drops empty query values", () => {
    expect(heatQuery({ metric: "unmet", kind: undefined, hourFrom: 0, hourTo: 23 })).toBe("metric=unmet&hourFrom=0&hourTo=23");
  });
});

describe("toResolution", () => {
  it("expands coarse cells to children and collapses fine ones", () => {
    const r7 = cellAt(11.0183, 76.9725, 7);
    const r9 = cellAt(11.0183, 76.9725, 9);
    expect(toResolution([r7], 8)).toHaveLength(7);
    expect(toResolution([r9], 8)).toHaveLength(1);
    expect(toResolution([r7, r7], 7)).toEqual([r7]);
  });
});

describe("travel speeds", () => {
  it("weights hourly speed by trips", async () => {
    const { speedByHour } = await import("@/lib/speeds");
    const rows = [
      { fromCell: "a", toCell: "b", hour: 8, trips: 3, avgSpeedKmh: 10, avgDurationMin: 12 },
      { fromCell: "a", toCell: "c", hour: 8, trips: 1, avgSpeedKmh: 30, avgDurationMin: 6 },
      { fromCell: "b", toCell: "c", hour: 18, trips: 2, avgSpeedKmh: 12, avgDurationMin: 9 },
    ];
    expect(speedByHour(rows)).toEqual([
      { hour: "08:00", speed: 15, trips: 4 },
      { hour: "18:00", speed: 12, trips: 2 },
    ]);
  });
});
