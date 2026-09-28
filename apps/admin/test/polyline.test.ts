import { describe, expect, it } from "vitest";

import { decodePolyline, formatKm } from "@/lib/polyline";

describe("decodePolyline", () => {
  it("decodes Google's documented example", () => {
    expect(decodePolyline("_p~iF~ps|U_ulLnnqC_mqNvxq`@")).toEqual([
      { lat: 38.5, lng: -120.2 },
      { lat: 40.7, lng: -120.95 },
      { lat: 43.252, lng: -126.453 },
    ]);
  });

  it("returns no points for empty or truncated input", () => {
    expect(decodePolyline("")).toEqual([]);
    expect(decodePolyline("_p~iF")).toEqual([]);
  });
});

describe("formatKm", () => {
  it("shows one decimal or a dash", () => {
    expect(formatKm(6149)).toBe("6.1 km");
    expect(formatKm(null)).toBe("–");
  });
});
