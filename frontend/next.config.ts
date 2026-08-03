import type { NextConfig } from "next";
import createNextIntlPlugin from "next-intl/plugin";

const withNextIntl = createNextIntlPlugin();

const nextConfig: NextConfig = {
  // Production on VPS: `next start` via systemd (see deploy/).
  // Never set output:"standalone" — incompatible with next start on Next 16
  // and previously hung on /gardenhouse/* routes.

  // Sub-path in production: NEXT_PUBLIC_BASE_PATH=/gardenhouse
  // Empty string for local `npm run dev` at domain root.
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