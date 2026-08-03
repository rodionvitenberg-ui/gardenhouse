import type { NextConfig } from "next";
import createNextIntlPlugin from "next-intl/plugin";

const withNextIntl = createNextIntlPlugin();

const nextConfig: NextConfig = {
  // Use classic `next start` on the VPS (systemd/PM2).
  // Do NOT set output:"standalone" here — Next 16 refuses `next start` with it,
  // and standalone server.js has been hanging on /gardenhouse/* in prod.

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