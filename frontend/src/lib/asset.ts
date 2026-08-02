/**
 * assetUrl — builds a URL for a file served from Next.js `public/`.
 *
 * In production the app runs under a basePath (e.g. /gardenhouse). Next.js
 * automatically prefixes `next/image`, `next/link` and `/_next/*`, but it
 * does NOT prefix plain `<img src>`, `<video src>`, `<source>` and CSS
 * `@font-face url()` — those would request `/video.mp4` instead of
 * `/gardenhouse/video.mp4` and 404. Use this helper anywhere a raw path
 * into `public/` is needed.
 */
export function assetUrl(path: string): string {
  if (!path) return path;
  // Already absolute or already base-pathed — leave untouched.
  if (path.startsWith("http://") || path.startsWith("https://") || path.startsWith("data:")) {
    return path;
  }
  const basePath = process.env.NEXT_PUBLIC_BASE_PATH || "";
  if (basePath && !path.startsWith(`${basePath}/`) && path.startsWith("/")) {
    return `${basePath}${path}`;
  }
  return path;
}