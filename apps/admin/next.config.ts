import path from "node:path";

import type { NextConfig } from "next";

// Monorepo root: dependencies are hoisted there by npm workspaces.
const repoRoot = path.join(__dirname, "../..");

const nextConfig: NextConfig = {
  // Docker: .next/standalone/apps/admin/server.js (see apps/admin/Dockerfile).
  output: "standalone",
  outputFileTracingRoot: repoRoot,
  turbopack: { root: repoRoot },
  poweredByHeader: false,
};

export default nextConfig;
