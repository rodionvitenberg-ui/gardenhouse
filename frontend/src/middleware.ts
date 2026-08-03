/**
 * Next.js 16 prefers `proxy.ts`, but some production resolvers still look for
 * `middleware.ts`. Keep both in sync — same next-intl entrypoint.
 */
export { default, config } from "./proxy";
