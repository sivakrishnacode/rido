import { describe, expect, it } from "vitest";

import { cancelSummary, faultSummary } from "@/lib/cancel";

describe("cancelSummary", () => {
  it("says who cancelled and why", () => {
    expect(cancelSummary("DRIVER", "VEHICLE_ISSUE")).toBe("Driver · Vehicle problem");
    expect(cancelSummary("SYSTEM", "NO_DRIVERS")).toBe("Rido (automatic) · No drivers available");
    expect(cancelSummary("PASSENGER", null)).toBe("Passenger");
    expect(cancelSummary(null, null)).toBe("Unknown");
  });
});

describe("faultSummary", () => {
  it("says who was at fault and which rule decided", () => {
    expect(faultSummary("PASSENGER", "passenger_after_wait")).toBe("Passenger's fault · passenger after wait");
    expect(faultSummary("NONE")).toBe("No fault");
    expect(faultSummary(null)).toBe("Not judged");
  });
});
