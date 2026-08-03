import type { Metadata } from "next";
import { routing } from "@/i18n/routing";
import JournalArticleClient from "./JournalArticleClient";

const BASE_URL = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";
const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8001/api";

async function getArticle(slug: string): Promise<{
  title: string;
  description: string;
  image: string;
  alt: string;
} | null> {
  try {
    const res = await fetch(`${API_URL}/journal/`, {
      next: { revalidate: 3600 },
    });
    if (!res.ok) return null;
    const items = await res.json();
    const list: { slug: string; title: string; description: string; image: string; alt: string }[] = Array.isArray(items) ? items : items.results ?? [];
    const article = list.find((a) => a.slug === slug);
    return article
      ? {
          title: article.title,
          description: article.description?.slice(0, 160) ?? "",
          image: article.image ?? "",
          alt: article.alt ?? article.title,
        }
      : null;
  } catch {
    return null;
  }
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string; slug: string }>;
}): Promise<Metadata> {
  const { locale, slug } = await params;
  const article = await getArticle(slug);

  const title = article?.title ?? slug;
  const description = article?.description
    ? article.description
    : `Read this journal entry from Father's Garden`;

  const alternates = {
    canonical: `${BASE_URL}/${locale}/journal/${slug}`,
    languages: Object.fromEntries(
      routing.locales.map((lng) => [`/${lng}/journal/${slug}`, `${BASE_URL}/${lng}/journal/${slug}`]),
    ),
  };

  return {
    title,
    description,
    alternates,
    openGraph: {
      title,
      description,
      url: `${BASE_URL}/${locale}/journal/${slug}`,
      type: "article",
      images: article?.image
        ? [{ url: article.image, width: 1200, height: 675, alt: article.alt }]
        : [],
    },
  };
}

export default function JournalArticlePage() {
  return <JournalArticleClient />;
}