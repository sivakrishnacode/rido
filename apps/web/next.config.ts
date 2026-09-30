import path from "node:path";

import type { NextConfig } from "next";

// Monorepo root: dependencies are hoisted there by npm workspaces.
const repoRoot = path.join(__dirname, "../..");

const nextConfig: NextConfig = {
  // Plain HTML/CSS/JS in out/: any static host (Caddy, GitHub Pages, S3) can serve it.
  output: "export",
  // /privacy → out/privacy/index.html, so static hosts need no rewrite rules.
  trailingSlash: true,
  // The default image loader needs a server; the screenshots are already sized WebP.
  images: { unoptimized: true },
  turbopack: { root: repoRoot },
  poweredByHeader: false,
};

export default nextConfig;
