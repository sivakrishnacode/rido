import type { MetadataRoute } from "next";

import { pages, site } from "@/lib/site";

export const dynamic = "force-static";

export default function sitemap(): MetadataRoute.Sitemap {
  return pages.map((path) => ({ url: new URL(path, site.url).toString() }));
}
