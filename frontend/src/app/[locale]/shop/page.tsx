import type { Metadata } from "next";
import { routing } from "@/i18n/routing";
import ShopPageClient from "./ShopPageClient";

const BASE_URL = "https://fathersgarden.kg";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const titles: Record<string, string> = {
    en: "Shop — Nursery Plants",
    ru: "Магазин — Растения из питомника",
  };
  const descriptions: Record<string, string> = {
    en: "Browse our collection of hardy perennials, trees, shrubs, and seeds — all grown in our nursery in Kyzyl-Suu, Lake Issyk-Kul.",
    ru: "Многолетники, деревья, кустарники и семена из нашего питомника в Кызыл-Суу, Иссык-Куль.",
  };

  const alternates = {
    canonical: `${BASE_URL}/${locale}/shop`,
    languages: Object.fromEntries(routing.locales.map((lng) => [lng, `${BASE_URL}/${lng}/shop`])),
  };

  return {
    title: titles[locale] ?? titles.en,
    description: descriptions[locale] ?? descriptions.en,
    alternates,
    openGraph: {
      title: titles[locale] ?? titles.en,
      description: descriptions[locale] ?? descriptions.en,
      url: `${BASE_URL}/${locale}/shop`,
      type: "website",
    },
  };
}

export default function ShopPage() {
  return <ShopPageClient />;
}