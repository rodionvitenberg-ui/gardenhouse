import type { MetadataRoute } from "next";

const BASE_URL = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";
const API_URL = process.env.API_URL || process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api";

type Locale = "en" | "ru";

const locales: Locale[] = ["en", "ru"];

const staticPaths: { path: string; priority: number; changeFrequency: MetadataRoute.Sitemap[number]["changeFrequency"] }[] = [
  { path: "", priority: 1.0, changeFrequency: "weekly" },
  { path: "/shop", priority: 0.9, changeFrequency: "daily" },
  { path: "/house", priority: 0.9, changeFrequency: "weekly" },
  { path: "/journal", priority: 0.8, changeFrequency: "weekly" },
  { path: "/about", priority: 0.7, changeFrequency: "monthly" },
  { path: "/contact", priority: 0.6, changeFrequency: "monthly" },
  { path: "/privacy", priority: 0.3, changeFrequency: "yearly" },
];

/** Fetch slugs from Django API. Falls back to empty if the API is unreachable. */
async function fetchSlugs(endpoint: string): Promise<string[]> {
  try {
    const res = await fetch(`${API_URL}/${endpoint}/`, {
      next: { revalidate: 3600 },
      headers: {
        "Accept-Language": "en",
        // Django runs with SECURE_SSL_REDIRECT=True in production. This header
        // lets the internal (plain-HTTP) request to Gunicorn be seen as secure,
        // avoiding a redirect loop on sitemap data fetching.
        "X-Forwarded-Proto": "https",
      },
    });
    if (!res.ok) return [];
    const data = await res.json();
    // DRF returns either a list or a paginated { results: [...] }
    const items: { slug: string }[] = Array.isArray(data) ? data : data.results ?? [];
    return items.map((item) => item.slug).filter(Boolean);
  } catch {
    return [];
  }
}

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const [productSlugs, journalSlugs] = await Promise.all([
    fetchSlugs("products"),
    fetchSlugs("journal"),
  ]);

  const entries: MetadataRoute.Sitemap = [];

  for (const locale of locales) {
    const langPrefix = `/${locale}`;

    for (const staticPath of staticPaths) {
      entries.push({
        url: `${BASE_URL}${langPrefix}${staticPath.path}`,
        lastModified: new Date(),
        changeFrequency: staticPath.changeFrequency,
        priority: staticPath.priority,
      });
    }

    for (const slug of productSlugs) {
      entries.push({
        url: `${BASE_URL}${langPrefix}/shop/${slug}`,
        lastModified: new Date(),
        changeFrequency: "weekly" as const,
        priority: 0.7,
      });
    }

    for (const slug of journalSlugs) {
      entries.push({
        url: `${BASE_URL}${langPrefix}/journal/${slug}`,
        lastModified: new Date(),
        changeFrequency: "monthly" as const,
        priority: 0.6,
      });
    }
  }

  return entries;
}