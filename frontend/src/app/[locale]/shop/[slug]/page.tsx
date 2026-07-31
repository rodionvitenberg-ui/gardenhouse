import type { Metadata } from "next";
import { routing } from "@/i18n/routing";
import ProductDetailClient from "./ProductDetailClient";

const BASE_URL = "https://fathersgarden.kg";
const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8001/api";

async function getProduct(slug: string): Promise<{
  title: string;
  description: string;
  image: string;
} | null> {
  try {
    // Fetch all products and find by slug — matches client-side logic
    const res = await fetch(`${API_URL}/products/`, {
      next: { revalidate: 3600 },
    });
    if (!res.ok) return null;
    const items = await res.json();
    const list: { slug: string; title: string; description: string; image: string }[] = Array.isArray(items) ? items : items.results ?? [];
    const product = list.find((p) => p.slug === slug);
    return product
      ? {
          title: product.title,
          description: product.description?.slice(0, 160) ?? "",
          image: product.image ?? "",
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
  const product = await getProduct(slug);

  const title = product?.title ? product.title : slug;
  const description = product?.description
    ? product.description
    : `Plant details — ${slug}`;

  const alternates = {
    canonical: `${BASE_URL}/${locale}/shop/${slug}`,
    languages: Object.fromEntries(
      routing.locales.map((lng) => [`/${lng}/shop/${slug}`, `${BASE_URL}/${lng}/shop/${slug}`]),
    ),
  };

  return {
    title,
    description,
    alternates,
    openGraph: {
      title,
      description,
      url: `${BASE_URL}/${locale}/shop/${slug}`,
      type: "website",
      images: product?.image
        ? [{ url: product.image, width: 800, height: 600, alt: title }]
        : [],
    },
  };
}

export default function ProductDetailPage() {
  return <ProductDetailClient />;
}