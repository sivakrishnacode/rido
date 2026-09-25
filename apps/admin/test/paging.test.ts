import { describe, expect, it } from "vitest";

import { apiBaseUrl, apiUrl, errorMessage, safeNext } from "@/lib/api-core";
import { decodeJwt, isUsableAdminToken } from "@/lib/jwt";
import { pageHref, pageInfo, pageWindow, parsePage, withQuery } from "@/lib/paging";

describe("paging URL builder", () => {
  it("skips empty values and ALL", () => {
    expect(withQuery("/drivers", { q: "", status: "ALL", page: 2, pageSize: 20 })).toBe("/drivers?page=2&pageSize=20");
    expect(withQuery("/drivers", { q: undefined, status: null })).toBe("/drivers");
    expect(withQuery("/trips", { q: "Gandhi puram" })).toBe("/trips?q=Gandhi+puram");
  });

  it("keeps filters and omits page 1 in page links", () => {
    expect(pageHref("/drivers", { status: "PENDING", q: "TN 37" }, 3)).toBe("/drivers?status=PENDING&q=TN+37&page=3");
    expect(pageHref("/drivers", { status: "PENDING", page: 3 }, 1)).toBe("/drivers?status=PENDING");
  });

  it("parses page params defensively", () => {
    expect(parsePage("4")).toBe(4);
    expect(parsePage(["2", "9"])).toBe(2);
    expect(parsePage("0")).toBe(1);
    expect(parsePage("abc")).toBe(1);
    expect(parsePage(undefined)).toBe(1);
  });

  it("computes ranges and page windows", () => {
    expect(pageInfo({ page: 2, pageSize: 20, total: 57 })).toEqual({ page: 2, pageCount: 3, from: 21, to: 40, hasPrev: true, hasNext: true });
    expect(pageInfo({ page: 1, pageSize: 20, total: 0 })).toMatchObject({ from: 0, to: 0, pageCount: 1, hasNext: false });
    expect(pageWindow(5, 10)).toEqual([1, "…", 4, 5, 6, "…", 10]);
    expect(pageWindow(2, 4)).toEqual([1, 2, 3, 4]);
  });
});

describe("api helpers", () => {
  it("resolves the base URL from API_URL", () => {
    expect(apiBaseUrl({})).toBe("http://localhost:3000/v1");
    expect(apiBaseUrl({ API_URL: "http://api:3000/v1/" })).toBe("http://api:3000/v1");
    expect(apiUrl("http://api:3000/v1", "admin/drivers", { page: 2, status: "ALL" })).toBe("http://api:3000/v1/admin/drivers?page=2");
  });

  it("reads API error bodies", () => {
    expect(errorMessage({ message: ["phone must be valid", "code too short"] }, 400)).toBe("phone must be valid, code too short");
    expect(errorMessage({ message: "Incorrect OTP" }, 401)).toBe("Incorrect OTP");
    expect(errorMessage(null, 404)).toBe("Not found");
    expect(errorMessage("", 500)).toBe("Request failed (500)");
  });

  it("only allows same-site post-login redirects", () => {
    expect(safeNext("/drivers?status=PENDING")).toBe("/drivers?status=PENDING");
    expect(safeNext("//evil.example")).toBe("/");
    expect(safeNext("https://evil.example")).toBe("/");
    expect(safeNext("/login")).toBe("/");
    expect(safeNext(undefined)).toBe("/");
  });

  it("checks admin JWTs optimistically", () => {
    const token = (claims: object) => `x.${Buffer.from(JSON.stringify(claims)).toString("base64url")}.sig`;
    expect(decodeJwt(token({ role: "ADMIN", exp: 10 }))).toEqual({ role: "ADMIN", exp: 10 });
    expect(isUsableAdminToken(token({ role: "ADMIN", exp: 2000 }), 1000)).toBe(true);
    expect(isUsableAdminToken(token({ role: "ADMIN", exp: 500 }), 1000)).toBe(false);
    expect(isUsableAdminToken(token({ role: "PASSENGER", exp: 2000 }), 1000)).toBe(false);
    expect(isUsableAdminToken("garbage", 1000)).toBe(false);
    expect(isUsableAdminToken(undefined)).toBe(false);
  });
});
