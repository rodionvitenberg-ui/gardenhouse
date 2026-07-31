"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { Link } from "@/i18n/navigation";
import { useTranslations } from "next-intl";
import Image from "next/image";
import InnerNav from "@/components/InnerNav";
import { fetchJournalArticleBySlug } from "@/lib/api";
import type { JournalArticle } from "@/types";

export default function JournalArticleClient() {
  const t = useTranslations("journal");
  const { slug } = useParams<{ slug: string }>();
  const [article, setArticle] = useState<JournalArticle | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchJournalArticleBySlug(slug)
      .then((data) => setArticle(data))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [slug]);

  if (loading) {
    return (
      <>
        <InnerNav />
        <div className="w-[98%] max-w-[2000px] mx-auto px-6 pt-4 md:pt-8 pb-24">
          <div className="max-w-[720px] mx-auto">
            <div className="h-3 w-24 bg-charcoal/5 animate-pulse rounded mb-4" />
            <div className="h-10 w-64 bg-charcoal/5 animate-pulse rounded mb-4" />
            <div className="aspect-[16/9] rounded-[20px] bg-charcoal/5 animate-pulse mb-8" />
            <div className="space-y-3">
              <div className="h-4 w-full bg-charcoal/5 animate-pulse rounded" />
              <div className="h-4 w-3/4 bg-charcoal/5 animate-pulse rounded" />
              <div className="h-4 w-5/6 bg-charcoal/5 animate-pulse rounded" />
            </div>
          </div>
        </div>
      </>
    );
  }

  if (!article) {
    return (
      <>
        <InnerNav />
        <div className="w-[98%] max-w-[2000px] mx-auto px-6 pt-4 md:pt-8 pb-24 text-center">
          <h1 className="text-heading-lg font-light text-charcoal mb-4">
            Article not found
          </h1>
          <Link
            href="/journal"
            className="inline-block rounded-[20px] bg-charcoal px-6 py-3 text-body font-regular text-snow hover:opacity-90 transition-opacity no-underline"
          >
            &larr; Back to journal
          </Link>
        </div>
      </>
    );
  }

  return (
    <>
      <InnerNav />
      <article className="w-[98%] max-w-[2000px] mx-auto px-6 pt-4 md:pt-8 pb-24">
        <div className="max-w-[720px] mx-auto">
          <Link
            href="/journal"
            className="inline-block text-body-sm font-regular text-charcoal/50 hover:text-charcoal transition-colors no-underline mb-8"
          >
            &larr; {t("title")}
          </Link>

          <div className="flex items-center gap-4 mb-4">
            <span className="rounded-[12px] bg-morning-sky/30 px-3 py-1 text-caption font-regular text-charcoal/70 uppercase tracking-[-0.06px]">
              {t(article.category)}
            </span>
            <span className="text-caption font-regular text-charcoal/40 tracking-[-0.06px]">
              {article.date}
            </span>
          </div>

          <h1 className="text-heading-lg md:text-display font-light text-charcoal leading-[0.95] tracking-[-0.8px] mb-8">
            {article.title}
          </h1>

          {article.image && (
            <div className="relative aspect-[16/9] overflow-hidden rounded-[20px] bg-paper mb-10">
              <Image
                src={article.image}
                alt={article.alt || article.title}
                fill
                className="object-cover"
                sizes="(max-width: 768px) 100vw, 720px"
                priority
              />
            </div>
          )}

          <div
            className="prose-custom text-body font-light text-charcoal leading-[1.29]"
            dangerouslySetInnerHTML={{ __html: article.content }}
          />
        </div>
      </article>
    </>
  );
}