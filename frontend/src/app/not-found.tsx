"use client";

import { useEffect, useState } from "react";
import Link from "next/link";

const messages: Record<string, { title: string; desc: string; home: string }> = {
  en: {
    title: "404",
    desc: "Page not found.",
    home: "Back to home",
  },
  ru: {
    title: "404",
    desc: "Страница не найдена.",
    home: "На главную",
  },
};

function detectLocale(): string {
  if (typeof window === "undefined") return "ru";
  const match = window.location.pathname.match(/^\/(ru|en)\b/);
  return match ? match[1] : "ru";
}

export default function NotFound() {
  const [locale, setLocale] = useState<string>("ru");

  useEffect(() => {
    setLocale(detectLocale());
  }, []);

  const t = messages[locale] ?? messages.ru;

  return (
    <html lang={locale}>
      <body className="bg-paper text-charcoal font-neue-haas-unica font-light antialiased flex items-center justify-center min-h-screen">
        <div className="text-center px-6 max-w-lg">
          <h1 className="text-[200px] font-light text-charcoal leading-[0.8] tracking-[-4px] mb-2 select-none">
            {t.title}
          </h1>
          <p className="text-subheading font-light text-charcoal/60 mb-12">
            {t.desc}
          </p>
          <Link
            href={`/${locale}`}
            className="inline-block rounded-[20px] bg-charcoal text-snow text-body font-regular px-6 py-3 transition-opacity hover:opacity-85 no-underline"
          >
            {t.home}
          </Link>
        </div>
      </body>
    </html>
  );
}