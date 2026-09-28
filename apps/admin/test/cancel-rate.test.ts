import { describe, expect, it } from "vitest";

import { validateSettings } from "@/lib/validation";

describe("driver cancellation rate settings", () => {
  it("accepts the defaults", () => {
    expect(validateSettings({ cancelRateMinTrips: 5, cancelRateNudge: 0.3, cancelRateBlock: 0.5, cancelBlockHours: 24, cancelBlockRepeatHours: 72 })).toEqual({});
  });

  it("keeps the warning below the pause and whole hours", () => {
    expect(validateSettings({ cancelRateNudge: 0.6, cancelRateBlock: 0.5 }).cancelRateNudge).toBe("Warn at can't be above Pause at");
    expect(validateSettings({ cancelBlockHours: 1.5 }).cancelBlockHours).toBeTruthy();
    expect(validateSettings({ cancelRateMinTrips: 0 }).cancelRateMinTrips).toBeTruthy();
  });
});
