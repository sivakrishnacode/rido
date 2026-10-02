import { describe, expect, it } from "vitest";

import { isCrossSiteRequest, publicUrl } from "@/lib/public-url";

describe("publicUrl", () => {
  it("uses the public host behind Caddy, not the container address", () => {
    const request = {
      url: "http://0.0.0.0:3001/files/a.jpg",
      headers: new Headers({ host: "admin.65-0-233-253.sslip.io", "x-forwarded-proto": "https" }),
    };
    expect(publicUrl(request, "/login").href).toBe("https://admin.65-0-233-253.sslip.io/login");
  });

  it("falls back to the request URL without proxy headers", () => {
    const request = { url: "http://localhost:3001/x", headers: new Headers({ host: "localhost:3001" }) };
    expect(publicUrl(request, "/login").href).toBe("http://localhost:3001/login");
  });
});

describe("isCrossSiteRequest", () => {
  const req = (site?: string) => new Headers(site ? { "sec-fetch-site": site } : {});

  it("refuses requests another site made the browser send", () => {
    expect(isCrossSiteRequest(req("cross-site"))).toBe(true);
    expect(isCrossSiteRequest(req("same-site"))).toBe(true);
  });

  it("allows this site's pages, their redirects, a typed address and old browsers", () => {
    expect(isCrossSiteRequest(req("same-origin"))).toBe(false);
    expect(isCrossSiteRequest(req("none"))).toBe(false);
    expect(isCrossSiteRequest(req())).toBe(false);
  });
});
