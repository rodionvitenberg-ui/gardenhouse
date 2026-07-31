import type { Metadata } from "next";
import { routing } from "@/i18n/routing";
import JournalPageClient from "./JournalPageClient";

const BASE_URL = "https://fathersgarden.kg";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const titles: Record<string, string> = {
    en: "Journal — Notes from the Garden",
    ru: "Журнал — Заметки из сада",
  };
  const descriptions: Record<string, string> = {
    en: "Gardening notes, seasonal tips, and guest stories from our nursery in Kyzyl-Suu, Lake Issyk-Kul.",
    ru: "Заметки садовода, сезонные советы и истории гостей из нашего питомника в Кызыл-Суу, Иссык-Куль.",
  };

  const alternates = {
    canonical: `${BASE_URL}/${locale}/journal`,
    languages: Object.fromEntries(routing.locales.map((lng) => [lng, `${BASE_URL}/${lng}/journal`])),
  };

  return {
    title: titles[locale] ?? titles.en,
    description: descriptions[locale] ?? descriptions.en,
    alternates,
    openGraph: {
      title: titles[locale] ?? titles.en,
      description: descriptions[locale] ?? descriptions.en,
      url: `${BASE_URL}/${locale}/journal`,
      type: "website",
    },
  };
}

export default function JournalPage() {
  return <JournalPageClient />;
}