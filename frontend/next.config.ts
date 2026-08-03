import type { NextConfig } from "next";
import createNextIntlPlugin from "next-intl/plugin";

const withNextIntl = createNextIntlPlugin();

const nextConfig: NextConfig = {
  // Standalone output — run with: node .next/standalone/server.js
  // Do NOT use `next start` when this is set (Next 16 warns and misbehaves).
  // deploy/start_frontend.sh and deploy/deploy.sh prepare public+static copies.
  output: "standalone",

  // Sub-path the app is served from (e.g. "/gardenhouse" in production).
  // Empty string when served at the domain root.
  basePath: process.env.NEXT_PUBLIC_BASE_PATH || "",
  images: {
    remotePatterns: [
      {
        protocol: "http",
        hostname: "localhost",
        port: "8000",
      },
      {
        protocol: "https",
        hostname: "images.unsplash.com",
      },
      {
        protocol: "https",
        hostname: "maintest.site",
      },
      {
        protocol: "http",
        hostname: "maintest.site",
      },
      {
        protocol: "http",
        hostname: "193.181.216.124",
      },
      {
        protocol: "https",
        hostname: "193.181.216.124",
      },
    ],
  },
};

export default withNextIntl(nextConfig);