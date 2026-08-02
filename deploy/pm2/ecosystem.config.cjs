// PM2 ecosystem config for the GardenHouse Next.js frontend.
// Started by deploy/deploy.sh via:
//   pm2 startOrReload /var/www/gardenhouse/deploy/pm2/ecosystem.config.cjs
//
// The app listens on 127.0.0.1:3000, behind nginx (location ^~ /gardenhouse).

module.exports = {
  apps: [
    {
      name: "gardenhouse-frontend",
      cwd: "/var/www/gardenhouse/frontend",
      script: "node_modules/next/dist/bin/next",
      args: "start -H 127.0.0.1 -p 3000",
      env: {
        NODE_ENV: "production",
      },
      // .env.production is loaded by Next.js automatically (it reads
      // .env.production during `next start`), no manual dotenv needed.
      instances: 1,
      exec_mode: "fork",
      autorestart: true,
      watch: false,
      max_memory_restart: "500M",
      time: true, // timestamped logs
    },
  ],
};