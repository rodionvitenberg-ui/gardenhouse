import type { Metadata } from "next";
import { NextIntlClientProvider } from "next-intl";
import { getMessages } from "next-intl/server";
import { routing } from "@/i18n/routing";
import { notFound } from "next/navigation";
import "../globals.css";
import Footer from "@/components/Footer";
import CookieConsent from "@/components/CookieConsent";
import { Geist } from "next/font/google";
import { cn } from "@/lib/utils";

const geist = Geist({ subsets: ["latin"], variable: "--font-sans" });

const BASE_URL = "https://fathersgarden.kg";

const localeNames: Record<string, string> = {
  en: "en_US",
  ru: "ru_RU",
};

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const localeTitle: Record<string, string> = {
    en: "Father's Garden — Nursery & Guest House in Kyzyl-Suu",
    ru: "Father's Garden — Питомник и гостевой дом в Кызыл-Суу",
  };
  const localeDesc: Record<string, string> = {
    en: "Browse our nursery of hardy perennials and book a stay in our guest house overlooking Lake Issyk-Kul. Garden-fresh plants, orchard views, and quiet nights under the stars.",
    ru: "Питомник многолетних растений и гостевой дом с видом на Иссык-Куль. Садовые растения, абрикосовый сад и тихие ночи под звёздами.",
  };

  const alternates = {
    canonical: `${BASE_URL}/${locale}`,
    languages: Object.fromEntries(
      routing.locales.map((lng) => [lng, `${BASE_URL}/${lng}`]),
    ),
  };

  return {
    metadataBase: new URL(BASE_URL),
    title: {
      template: `%s — Father's Garden`,
      default: localeTitle[locale] ?? localeTitle.en,
    },
    description: localeDesc[locale] ?? localeDesc.en,
    alternates,
    openGraph: {
      title: localeTitle[locale] ?? localeTitle.en,
      description: localeDesc[locale] ?? localeDesc.en,
      url: `${BASE_URL}/${locale}`,
      siteName: "Father's Garden",
      locale: localeNames[locale] ?? "en_US",
      type: "website",
      images: [
        {
          url: "/og-image.jpg",
          width: 1200,
          height: 630,
          alt: "Father's Garden — orchard and guest house",
        },
      ],
    },
    icons: {
      icon: "/favicon.svg",
      apple: "/favicon.svg",
    },
    robots: {
      index: true,
      follow: true,
    },
  };
}

export default async function LocaleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;

  if (!routing.locales.includes(locale as "en" | "ru")) {
    notFound();
  }

  const messages = await getMessages();

  return (
    <html lang={locale} className={cn("font-sans", geist.variable)}>
      <body className="min-h-dvh flex flex-col bg-paper text-charcoal font-neue-haas-unica font-light antialiased">
        <NextIntlClientProvider messages={messages}>
          <main className="flex-1">{children}</main>
          <Footer />
          <CookieConsent />
        </NextIntlClientProvider>
      </body>
    </html>
  );
}