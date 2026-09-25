import { describe, expect, it } from "vitest";

import { displayName, formatDate, formatInr, formatPhone, humanize, kycProgress, shortId } from "@/lib/format";
import type { KycDocument } from "@/lib/types";

describe("formatInr", () => {
  it("uses Indian digit grouping with a rupee sign", () => {
    expect(formatInr(1420)).toBe("₹1,420");
    expect(formatInr(123456)).toBe("₹1,23,456");
    expect(formatInr(10000000)).toBe("₹1,00,00,000");
  });

  it("handles zero, negatives, decimals and missing values", () => {
    expect(formatInr(0)).toBe("₹0");
    expect(formatInr(-38)).toBe("-₹38");
    expect(formatInr(37.6)).toBe("₹38");
    expect(formatInr(null)).toBe("₹0");
    expect(formatInr(Number.NaN)).toBe("₹0");
  });
});

describe("other formatters", () => {
  it("formats Indian mobile numbers", () => {
    expect(formatPhone("+919000000001")).toBe("+91 90000 00001");
    expect(formatPhone("12345")).toBe("12345");
    expect(formatPhone(null)).toBe("–");
  });

  it("formats dates in IST", () => {
    // 20:00 UTC on 24 Sep is already 25 Sep in Coimbatore.
    expect(formatDate("2026-09-24T20:00:00Z")).toBe("25 Sep 2026");
  });

  it("humanizes enums, shortens ids, falls back to phone for names", () => {
    expect(humanize("IN_PROGRESS")).toBe("In progress");
    expect(shortId("cmuh3oalh00095rya68imfvo3")).toBe("68IMFVO3");
    expect(displayName({ name: null, phone: "+919000000001" })).toBe("+91 90000 00001");
    expect(displayName({ name: " Karthik S ", phone: "+919000000001" })).toBe("Karthik S");
  });

  it("counts verified KYC documents out of 5", () => {
    const doc = (status: KycDocument["status"]) => ({ status }) as KycDocument;
    expect(kycProgress([doc("VERIFIED"), doc("REJECTED"), doc("VERIFIED")])).toEqual({ verified: 2, total: 5 });
  });
});
