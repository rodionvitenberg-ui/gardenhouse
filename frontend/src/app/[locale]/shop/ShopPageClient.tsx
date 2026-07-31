"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useSearchParams } from "next/navigation";
import { Link } from "@/i18n/navigation";
import Image from "next/image";
import InnerNav from "@/components/InnerNav";
import { fetchProducts } from "@/lib/api";
import type { Product } from "@/types";

export default function ShopPageClient() {
  const t = useTranslations("shop");
  const [products, setProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<string[]>([]);
  const [activeCategory, setActiveCategory] = useState<string | null>(null);
  const [loaded, setLoaded] = useState(false);

  const searchParams = useSearchParams();

  useEffect(() => {
    fetchProducts()
      .then((data) => {
        setProducts(data);
        const cats = [
          ...new Set(
            data.map((p) => p.category?.title).filter(Boolean)
          ),
        ] as string[];
        setCategories(cats);

        // Read ?category= from URL and auto-select (match by slug from API)
        const categoryParam = searchParams.get("category");
        if (categoryParam) {
          const cat = data.find(
            (p) => p.category?.slug?.toLowerCase() === categoryParam.toLowerCase()
          );
          if (cat?.category?.title) setActiveCategory(cat.category.title);
        }
      })
      .catch(() => {})
      .finally(() => setLoaded(true));
  }, [searchParams]);

  const filtered = activeCategory
    ? products.filter((p) => p.category?.title === activeCategory)
    : products;

  return (
    <>
      <InnerNav />
      <main className="w-[98%] max-w-[2000px] mx-auto px-6 pt-4 md:pt-8 pb-24">
        <div className="max-w-[600px] mb-12 md:mb-20">
          <h1 className="text-display font-light text-charcoal leading-[0.95] tracking-[-0.8px] mb-4">
            {t("title")}
          </h1>
          <p className="text-subheading font-light text-charcoal leading-[1.22] max-w-[480px]">
            {t("heroText")}
          </p>
        </div>

        {!loaded && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6 md:gap-8">
            {Array.from({ length: 4 }).map((_, i) => {
              const isFeatured = i % 5 === 0;
              return (
                <div key={i} className={`space-y-4 ${isFeatured ? "md:col-span-4" : ""}`}>
                  <div className={`rounded-[20px] bg-charcoal/5 animate-pulse ${
                    isFeatured ? "aspect-[16/7] md:aspect-[21/7]" : "aspect-[4/5]"
                  }`} />
                  <div className="h-3 w-16 bg-charcoal/5 animate-pulse rounded" />
                  <div className="h-5 w-48 bg-charcoal/5 animate-pulse rounded" />
                </div>
              );
            })}
          </div>
        )}

        {loaded && products.length > 0 && (
          <div>
            {categories.length > 1 && (
              <div className="flex flex-wrap gap-3 mb-12">
                <button
                  onClick={() => setActiveCategory(null)}
                  className={`rounded-[99px] border-2 px-5 py-1.5 text-body-sm font-regular transition-colors ${
                    activeCategory === null
                      ? "bg-charcoal text-snow border-charcoal"
                      : "border-charcoal text-charcoal hover:bg-charcoal/5"
                  }`}
                >
                  {t("allProducts")}
                </button>
                {categories.map((cat) => (
                  <button
                    key={cat}
                    onClick={() => setActiveCategory(cat)}
                    className={`rounded-[99px] border-2 px-5 py-1.5 text-body-sm font-regular transition-colors ${
                      activeCategory === cat
                        ? "bg-charcoal text-snow border-charcoal"
                        : "border-charcoal text-charcoal hover:bg-charcoal/5"
                    }`}
                  >
                    {cat}
                  </button>
                ))}
              </div>
            )}

            <div className="grid grid-cols-1 md:grid-cols-4 gap-6 md:gap-8">
              {filtered.map((product, i) => {
                const isFeatured = i % 5 === 0;
                return (
                  <Link
                    key={product.id}
                    href={`/shop/${product.slug}`}
                    className={`block no-underline group ${
                      isFeatured ? "md:col-span-4" : ""
                    }`}
                    style={{
                      animationName: "shopCardReveal",
                      animationDuration: "0.6s",
                      animationFillMode: "both",
                      animationTimingFunction:
                        "cubic-bezier(0.16, 1, 0.3, 1)",
                      animationDelay: `${i * 80}ms`,
                    }}
                  >
                    <div
                      className={`relative overflow-hidden rounded-[20px] bg-paper mb-4 ${
                        isFeatured
                          ? "aspect-[16/7] md:aspect-[21/7]"
                          : "aspect-[4/5]"
                      }`}
                    >
                      {product.image ? (
                        <Image
                          src={product.image}
                          alt={product.title}
                          fill
                          className="object-cover group-hover:scale-[1.02] transition-transform duration-700 ease-out"
                          sizes={
                            isFeatured
                              ? "100vw"
                              : "(max-width: 768px) 100vw, 25vw"
                          }
                        />
                      ) : (
                        <div className="absolute inset-0 flex items-center justify-center bg-charcoal/5">
                          <span className="text-caption font-regular text-charcoal/20 uppercase tracking-[-0.06px]">
                            {t("noImage")}
                          </span>
                        </div>
                      )}
                    </div>
                    <p className="text-caption font-regular text-charcoal/40 uppercase tracking-[-0.06px] mb-1">
                      {product.category?.title ?? t("fallbackCategory")}
                    </p>
                    <p className="text-subheading font-light text-charcoal leading-[1.22]">
                      {product.title}
                    </p>
                    <p className="text-body font-regular text-charcoal/60 mt-1 tabular-nums">
                      ${product.price}
                    </p>
                  </Link>
                );
              })}
            </div>

            {filtered.length === 0 && (
              <p className="text-subheading font-light text-charcoal/50 py-16 text-center">
                {t("emptyCategory")}
              </p>
            )}
          </div>
        )}

        {loaded && products.length === 0 && (
          <div className="py-24 text-center">
            <p className="text-subheading font-light text-charcoal/50">
              {t("emptyAll")}
            </p>
          </div>
        )}
      </main>

      <style>{`
        @keyframes shopCardReveal {
          from {
            opacity: 0;
            transform: translateY(24px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
      `}</style>
    </>
  );
}