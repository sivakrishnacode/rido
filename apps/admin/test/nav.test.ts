import { describe, expect, it } from "vitest";

import { NAV, NAV_GROUPS, activeNav, groupOf } from "@/components/layout/nav";

describe("activeNav", () => {
  it("picks the longest matching item", () => {
    expect(activeNav("/").href).toBe("/");
    expect(activeNav("/drivers").href).toBe("/drivers");
    expect(activeNav("/drivers/cm123").href).toBe("/drivers");
    expect(activeNav("/drivers/approvals").href).toBe("/drivers/approvals");
    expect(activeNav("/trips/abc").href).toBe("/trips");
  });

  it("falls back to the dashboard for unknown paths", () => {
    expect(activeNav("/nowhere").href).toBe("/");
  });

  it("puts each page in its collection", () => {
    expect(groupOf(activeNav("/drivers/approvals")).label).toBe("Drivers");
    expect(groupOf(activeNav("/users/abc")).label).toBe("Riders");
    expect(groupOf(activeNav("/safety")).label).toBe("Trips");
  });

  it("lists every page once", () => {
    const hrefs = NAV.map((n) => n.href);
    expect(new Set(hrefs).size).toBe(hrefs.length);
    expect(NAV_GROUPS.every((g) => g.items.length > 0)).toBe(true);
  });
});
