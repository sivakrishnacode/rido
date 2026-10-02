import { existsSync, readFileSync } from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

import { deletion, privacy, terms } from "@/lib/legal";
import { openGraphBase, pages, playStoreUrl, site } from "@/lib/site";

const repoRoot = path.resolve(__dirname, "../../..");
const appDir = path.resolve(__dirname, "../src/app");
const publicDir = path.resolve(__dirname, "../public");

describe("site config", () => {
  it("links each Play Store button to the app's real applicationId", () => {
    const gradle = { rider: "passenger", driver: "driver" } as const;
    for (const [app, folder] of Object.entries(gradle) as [keyof typeof gradle, string][]) {
      const file = readFileSync(path.join(repoRoot, `apps/${folder}/android/app/build.gradle.kts`), "utf8");
      const applicationId = /applicationId\s*=\s*"([^"]+)"/.exec(file)?.[1];
      expect(applicationId).toBe(site.apps[app].packageId);
      expect(playStoreUrl(app)).toBe(`https://play.google.com/store/apps/details?id=${applicationId}`);
    }
  });

  it("lists only pages that exist in the sitemap", () => {
    for (const page of pages) {
      expect(existsSync(path.join(appDir, page, "page.tsx")), page).toBe(true);
    }
  });

  it("ships the social preview image at the size it declares, and a favicon", () => {
    const [image] = openGraphBase.images;
    const png = readFileSync(path.join(publicDir, image.url));
    // PNG header: width and height are big-endian at bytes 16 and 20.
    expect(png.subarray(1, 4).toString("ascii")).toBe("PNG");
    expect([png.readUInt32BE(16), png.readUInt32BE(20)]).toEqual([image.width, image.height]);
    expect(existsSync(path.join(appDir, "favicon.ico"))).toBe(true);
  });
});

describe("legal text", () => {
  it("dates both documents and gives a way to reach us", () => {
    for (const doc of [privacy, terms]) {
      expect(doc.updated).toMatch(/^\d{1,2} \w+ \d{4}$/);
      expect(doc.sections.some((s) => s.paragraphs.some((p) => p.includes(site.email)))).toBe(true);
    }
  });

  it("promises nothing the apps don't do", () => {
    const text = [privacy, terms]
      .flatMap((doc) => doc.sections.flatMap((s) => [...s.paragraphs, ...(s.list ?? [])]))
      .concat(deletion.deleted, deletion.kept)
      .join("\n");
    // There is no tip feature, police verification is no longer collected, drivers can't export their data, and no
    // job deletes trip records after a fixed time.
    expect(text).not.toMatch(/\btips?\b|police verification|download your data|\d+ years?/i);
  });

  it("links the privacy policy to the account deletion page", () => {
    const links = privacy.sections.flatMap((s) => (s.link ? [s.link.href] : []));
    expect(links).toContain("/delete-account/");
    expect(pages).toContain("/delete-account/");
  });
});
