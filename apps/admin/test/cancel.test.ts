import { describe, expect, it } from "vitest";

import { cancelSummary } from "@/lib/cancel";

describe("cancelSummary", () => {
  it("says who cancelled and why", () => {
    expect(cancelSummary("DRIVER", "VEHICLE_ISSUE")).toBe("Driver · Vehicle problem");
    expect(cancelSummary("SYSTEM", "NO_DRIVERS")).toBe("Rido (automatic) · No drivers available");
    expect(cancelSummary("PASSENGER", null)).toBe("Passenger");
    expect(cancelSummary(null, null)).toBe("Unknown");
  });
});
