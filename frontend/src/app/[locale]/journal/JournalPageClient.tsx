"use client";

import { useEffect, useState, useMemo } from "react";
import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import Image from "next/image";
import InnerNav from "@/components/InnerNav";
import { fetchJournalArticles } from "@/lib/api";
import type { JournalArticle } from "@/types";

const categories = ["all", "gardenNotes", "seasonalTips", "guestStories"] as const;

export default function JournalPageClient() {
  const t = useTranslations("journal");
  const [articles, setArticles] = useState<JournalArticle[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeFilter, setActiveFilter] = useState<string>("all");

  useEffect(() => {
    fetchJournalArticles()
      .then((data) => setArticles(data))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const filtered = useMemo(
    () =>
      activeFilter === "all"
        ? articles
        : articles.filter((a) => a.category === activeFilter),
    [activeFilter, articles],
  );

  return (
    <>
      <InnerNav />

      <div className="w-[98%] max-w-[2000px] mx-auto px-6 pb-24">
        {/* Desktop feed */}
        <div className="hidden md:block w-full">
          <div className="w-full px-6">
            <div className="mb-10 md:mb-12 pt-8 md:pt-12">
              <h1 className="text-heading-lg md:text-display font-light text-charcoal leading-[0.95] tracking-[-0.8px] mb-4">
                {t("title")}
              </h1>
              <p className="text-subheading font-light text-charcoal/60 leading-[1.22] tracking-[-0.18px] max-w-[480px]">
                {t("subtitle")}
              </p>
            </div>

            <div className="mb-10 flex flex-wrap gap-3">
              {categories.map((cat) => {
                const label = cat === "all" ? t("all") : t(cat);
                const isActive = activeFilter === cat;
                return (
                  <button
                    key={cat}
                    onClick={() => setActiveFilter(cat)}
                    className={
                      isActive
                        ? "rounded-[99px] bg-charcoal px-5 py-2 text-body-sm font-regular text-snow transition-colors tracking-[-0.07px]"
                        : "rounded-[99px] border border-charcoal/30 px-5 py-2 text-body-sm font-regular text-charcoal/70 hover:border-charcoal hover:text-charcoal transition-colors tracking-[-0.07px]"
                    }
                  >
                    {label}
                  </button>
                );
              })}
            </div>

            {loading && (
              <div className="space-y-8">
                {Array.from({ length: 4 }).map((_, i) => (
                  <div key={i} className="flex gap-6">
                    <div className="w-[200px] aspect-[4/3] rounded-[20px] bg-charcoal/5 animate-pulse shrink-0" />
                    <div className="flex-1 space-y-3">
                      <div className="h-5 w-24 bg-charcoal/5 animate-pulse rounded" />
                      <div className="h-6 w-48 bg-charcoal/5 animate-pulse rounded" />
                      <div className="h-4 w-full bg-charcoal/5 animate-pulse rounded" />
                    </div>
                  </div>
                ))}
              </div>
            )}

            {!loading && (
              <div className="space-y-10 md:space-y-10">
                {filtered.map((entry) => (
                  <Link
                    key={entry.id}
                    href={`/journal/${entry.slug}`}
                    className="flex flex-col md:flex-row gap-4 md:gap-8 items-start no-underline group"
                  >
                    <div className="relative w-full md:w-[200px] aspect-[4/3] shrink-0 overflow-hidden rounded-[20px] bg-paper">
                      {entry.image ? (
                        <Image
                          src={entry.image}
                          alt={entry.alt || entry.title}
                          fill
                          className="object-cover group-hover:scale-[1.02] transition-transform duration-700 ease-out"
                          sizes="(max-width: 768px) 100vw, 200px"
                        />
                      ) : (
                        <div className="absolute inset-0 bg-charcoal/5" />
                      )}
                    </div>

                    <div className="flex-1 min-w-0">
                      <span className="inline-block rounded-[12px] bg-morning-sky/30 px-3 py-1 text-caption font-regular text-charcoal/70 uppercase tracking-[-0.06px] mb-3">
                        {t(entry.category)}
                      </span>
                      <h3 className="text-heading-sm font-light text-charcoal leading-[1.15] tracking-[-0.33px] mb-2 group-hover:text-pine transition-colors">
                        {entry.title}
                      </h3>
                      <p className="text-body-sm font-light text-charcoal/65 leading-[1.33] mb-2">
                        {entry.description}
                      </p>
                      <span className="text-caption font-regular text-charcoal/40 tracking-[-0.06px]">
                        {entry.date}
                      </span>
                    </div>
                  </Link>
                ))}
                {filtered.length === 0 && (
                  <p className="text-subheading font-light text-charcoal/50 py-8">
                    Nothing here yet.
                  </p>
                )}
              </div>
            )}
          </div>
        </div>

        {/* Mobile feed */}
        <div className="md:hidden">
          <div className="mb-10 pt-8">
            <h1 className="text-heading-lg font-light text-charcoal leading-[0.95] tracking-[-0.8px] mb-4">
              {t("title")}
            </h1>
            <p className="text-subheading font-light text-charcoal/60 leading-[1.22] tracking-[-0.18px] max-w-[480px]">
              {t("subtitle")}
            </p>
          </div>

          <div className="mb-10 flex flex-wrap gap-3">
            {categories.map((cat) => {
              const label = cat === "all" ? t("all") : t(cat);
              const isActive = activeFilter === cat;
              return (
                <button
                  key={cat}
                  onClick={() => setActiveFilter(cat)}
                  className={
                    isActive
                      ? "rounded-[99px] bg-charcoal px-5 py-2 text-body-sm font-regular text-snow transition-colors tracking-[-0.07px]"
                      : "rounded-[99px] border border-charcoal/30 px-5 py-2 text-body-sm font-regular text-charcoal/70 hover:border-charcoal hover:text-charcoal transition-colors tracking-[-0.07px]"
                  }
                >
                  {label}
                </button>
              );
            })}
          </div>

          {loading && (
            <div className="space-y-6">
              {Array.from({ length: 3 }).map((_, i) => (
                <div key={i} className="space-y-3">
                  <div className="w-full aspect-[4/3] rounded-[20px] bg-charcoal/5 animate-pulse" />
                  <div className="h-5 w-24 bg-charcoal/5 animate-pulse rounded" />
                  <div className="h-6 w-48 bg-charcoal/5 animate-pulse rounded" />
                </div>
              ))}
            </div>
          )}

          {!loading && (
            <div className="space-y-8">
              {filtered.map((entry) => (
                <Link
                  key={entry.id}
                  href={`/journal/${entry.slug}`}
                  className="flex flex-col gap-5 items-start no-underline group"
                >
                  <div className="relative w-full aspect-[4/3] shrink-0 overflow-hidden rounded-[20px] bg-paper">
                    {entry.image ? (
                      <Image
                        src={entry.image}
                        alt={entry.alt || entry.title}
                        fill
                        className="object-cover group-hover:scale-[1.02] transition-transform duration-700 ease-out"
                        sizes="100vw"
                      />
                    ) : (
                      <div className="absolute inset-0 bg-charcoal/5" />
                    )}
                  </div>

                  <div className="flex-1 min-w-0">
                    <span className="inline-block rounded-[12px] bg-morning-sky/30 px-3 py-1 text-caption font-regular text-charcoal/70 uppercase tracking-[-0.06px] mb-3">
                      {t(entry.category)}
                    </span>
                    <h3 className="text-heading-sm font-light text-charcoal leading-[1.15] tracking-[-0.33px] mb-2 group-hover:text-pine transition-colors">
                      {entry.title}
                    </h3>
                    <p className="text-body-sm font-light text-charcoal/65 leading-[1.33] mb-2">
                      {entry.description}
                    </p>
                    <span className="text-caption font-regular text-charcoal/40 tracking-[-0.06px]">
                      {entry.date}
                    </span>
                  </div>
                </Link>
              ))}
              {filtered.length === 0 && (
                <p className="text-subheading font-light text-charcoal/50 py-8">
                  Nothing here yet.
                </p>
              )}
            </div>
          )}
        </div>
      </div>
    </>
  );
}