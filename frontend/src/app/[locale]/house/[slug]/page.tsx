import type { Metadata } from "next";
import { routing } from "@/i18n/routing";
import HouseDetailClient from "./HouseDetailClient";

const BASE_URL = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";
const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8001/api";

async function getHouse(slug: string): Promise<{
  title: string;
  description: string;
  image: string;
} | null> {
  try {
    const res = await fetch(`${API_URL}/houses/`, {
      next: { revalidate: 3600 },
    });
    if (!res.ok) return null;
    const items = await res.json();
    const list: { slug: string; title: string; description: string; images: { image: string }[] }[] =
      Array.isArray(items) ? items : items.results ?? [];
    const house = list.find((h) => h.slug === slug);
    return house
      ? {
          title: house.title,
          description: house.description?.slice(0, 160) ?? "",
          image: house.images?.[0]?.image ?? "",
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
  const house = await getHouse(slug);

  const title = house?.title ? `${house.title} — Guest House` : slug;
  const description = house?.description
    ? house.description
    : `Book a stay at our guest house in Kyzyl-Suu`;

  const alternates = {
    canonical: `${BASE_URL}/${locale}/house/${slug}`,
    languages: Object.fromEntries(
      routing.locales.map((lng) => [`/${lng}/house/${slug}`, `${BASE_URL}/${lng}/house/${slug}`]),
    ),
  };

  return {
    title,
    description,
    alternates,
    openGraph: {
      title,
      description,
      url: `${BASE_URL}/${locale}/house/${slug}`,
      type: "website",
      images: house?.image
        ? [{ url: house.image, width: 1200, height: 800, alt: title }]
        : [],
    },
  };
}

export default function HouseDetailPage() {
  return <HouseDetailClient />;
}