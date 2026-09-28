import { describe, expect, it } from "vitest";

import { validateSettings } from "@/lib/validation";

describe("cancellation fee settings", () => {
  it("is an on/off switch and a whole-rupee fee", () => {
    expect(validateSettings({ cancellationFeeEnabled: false, cancellationFee: 10 })).toEqual({});
    expect(validateSettings({ cancellationFeeEnabled: "yes" as unknown as boolean }).cancellationFeeEnabled).toBeTruthy();
    expect(validateSettings({ cancellationFee: 10.5 }).cancellationFee).toBeTruthy();
    expect(validateSettings({ cancellationFee: 501 }).cancellationFee).toBeTruthy();
  });
});
