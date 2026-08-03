// PM2 ecosystem — GardenHouse Next.js (standalone output)
//
// next.config has `output: "standalone"`. Do NOT run `next start`.
// Correct entrypoint: node .next/standalone/server.js
//
// After every `next build`, deploy.sh copies public/ and .next/static
// into the standalone folder (required by Next).
//
//   sudo -u maintest env PM2_HOME=/home/maintest/.pm2 \
//     pm2 startOrReload /var/www/gardenhouse/deploy/pm2/ecosystem.config.cjs

module.exports = {
  apps: [
    {
      name: "gardenhouse-frontend",
      cwd: "/var/www/gardenhouse/frontend/.next/standalone",
      script: "server.js",
      env: {
        NODE_ENV: "production",
        // Bind only localhost — nginx is the public face.
        HOSTNAME: "127.0.0.1",
        PORT: "3000",
      },
      instances: 1,
      exec_mode: "fork",
      autorestart: true,
      watch: false,
      max_memory_restart: "500M",
      time: true,
      kill_timeout: 10000,
      listen_timeout: 15000,
      wait_ready: false,
    },
  ],
};
