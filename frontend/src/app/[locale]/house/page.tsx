import type { Metadata } from "next";
import { routing } from "@/i18n/routing";
import HousesPageClient from "./HousesPageClient";

const BASE_URL = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const titles: Record<string, string> = {
    en: "Guest House — Stay with us",
    ru: "Гостевой дом — Остановитесь у нас",
  };
  const descriptions: Record<string, string> = {
    en: "One house. Two guests. An orchard of apricot trees and a sky full of stars. Book your stay at GardenHouse in Kyzyl-Suu, Lake Issyk-Kul.",
    ru: "Один дом. Два гостя. Абрикосовый сад и небо, полное звёзд. Забронируйте проживание в GardenHouse, Кызыл-Суу, Иссык-Куль.",
  };

  const alternates = {
    canonical: `${BASE_URL}/${locale}/house`,
    languages: Object.fromEntries(routing.locales.map((lng) => [lng, `${BASE_URL}/${lng}/house`])),
  };

  return {
    title: titles[locale] ?? titles.en,
    description: descriptions[locale] ?? descriptions.en,
    alternates,
    openGraph: {
      title: titles[locale] ?? titles.en,
      description: descriptions[locale] ?? descriptions.en,
      url: `${BASE_URL}/${locale}/house`,
      type: "website",
    },
  };
}

export default function HousesPage() {
  return <HousesPageClient />;
}