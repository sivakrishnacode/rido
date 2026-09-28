import { describe, expect, it } from "vitest";

import { validateSettings } from "@/lib/validation";

describe("waiting charge settings", () => {
  it("accepts whole minutes and rupees in range", () => {
    expect(validateSettings({ freeWaitMin: 3, waitMaxCharge: 30 })).toEqual({});
    expect(validateSettings({ freeWaitMin: 0, waitMaxCharge: 0 })).toEqual({});
  });

  it("refuses fractions and out-of-range values", () => {
    expect(validateSettings({ freeWaitMin: 2.5 }).freeWaitMin).toBeTruthy();
    expect(validateSettings({ freeWaitMin: 31 }).freeWaitMin).toBeTruthy();
    expect(validateSettings({ waitMaxCharge: -1 }).waitMaxCharge).toBeTruthy();
  });
});
