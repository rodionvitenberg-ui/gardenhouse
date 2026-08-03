// PM2 — GardenHouse Next.js (`next start`, NOT standalone)
//
//   sudo -u maintest env PM2_HOME=/home/maintest/.pm2 PATH=/usr/bin:/usr/local/bin:$PATH \
//     pm2 startOrReload /var/www/gardenhouse/deploy/pm2/ecosystem.config.cjs

module.exports = {
  apps: [
    {
      name: "gardenhouse-frontend",
      cwd: "/var/www/gardenhouse/frontend",
      script: "node_modules/next/dist/bin/next",
      args: "start -H 127.0.0.1 -p 3000",
      env: {
        NODE_ENV: "production",
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
      wait_ready: false,
    },
  ],
};
