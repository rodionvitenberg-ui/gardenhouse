/**
 * Absolute API base for server-side fetch (RSC, generateMetadata, sitemap).
 *
 * Never use NEXT_PUBLIC_API_URL (/gardenhouse/api) on the server: relative URLs
 * resolve to the Next process itself and can deadlock (request waits on itself)
 * or hit nginx-less paths. Browser code should keep using NEXT_PUBLIC_API_URL.
 */
export function getServerApiUrl(): string {
  const fromEnv = process.env.API_URL?.trim();
  if (fromEnv && /^https?:\/\//i.test(fromEnv)) {
    return fromEnv.replace(/\/$/, "");
  }
  // Prefer loopback Gunicorn — same as deploy .env.production API_URL=
  return "http://127.0.0.1:8000/api";
}
