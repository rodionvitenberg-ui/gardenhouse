"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import Image from "next/image";
import CTAButton from "@/components/CTAButton";
import InnerNav from "@/components/InnerNav";
import { fetchProductBySlug, createOrder } from "@/lib/api";
import type { Product, OrderCreatePayload } from "@/types";

function StatusLabel({ status, t }: { status: Product["status"]; t: (key: string) => string }) {
  const styles: Record<
    Product["status"],
    { label: string; className: string }
  > = {
    AVAILABLE: { label: t("statusInStock"), className: "text-pine" },
    PREORDER: {
      label: t("statusPreorder"),
      className: "text-charcoal/60",
    },
    OUT_OF_STOCK: { label: t("statusOutOfStock"), className: "text-charcoal/40" },
  };
  const s = styles[status];
  return (
    <p
      className={`text-caption font-regular uppercase tracking-[-0.06px] ${s.className}`}
    >
      {s.label}
    </p>
  );
}

export default function ProductDetailClient() {
  const t = useTranslations("shop");
  const { slug } = useParams<{ slug: string }>();
  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState(true);
  const [showOrderForm, setShowOrderForm] = useState(false);
  const [orderForm, setOrderForm] = useState({ guest_name: "", guest_phone: "" });
  const [orderSuccess, setOrderSuccess] = useState(false);
  const [orderSubmitting, setOrderSubmitting] = useState(false);
  const [orderError, setOrderError] = useState("");

  useEffect(() => {
    fetchProductBySlug(slug)
      .then((p) => {
        setProduct(p);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, [slug]);

  if (loading) {
    return (
      <>
        <InnerNav />
        <div className="w-[98%] max-w-[2000px] mx-auto px-6 py-12">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-12">
            <div className="aspect-[4/3] rounded-[20px] bg-charcoal/5 animate-pulse" />
            <div className="space-y-4">
              <div className="h-3 w-24 bg-charcoal/5 animate-pulse rounded" />
              <div className="h-8 w-64 bg-charcoal/5 animate-pulse rounded" />
              <div className="h-5 w-20 bg-charcoal/5 animate-pulse rounded" />
              <div className="h-4 w-full bg-charcoal/5 animate-pulse rounded" />
              <div className="h-4 w-3/4 bg-charcoal/5 animate-pulse rounded" />
              <div className="h-12 w-40 bg-charcoal/5 animate-pulse rounded-[20px] mt-6" />
            </div>
          </div>
        </div>
      </>
    );
  }

  if (!product) {
    return (
      <>
        <InnerNav />
        <div className="w-[98%] max-w-[2000px] mx-auto px-6 py-24 text-center">
          <h1 className="text-heading-lg font-light text-charcoal mb-4">
            {t("detailNotFound")}
          </h1>
          <p className="text-subheading font-light text-charcoal/50 mb-8 max-w-[400px] mx-auto">
            {t("detailNotFoundDesc")}
          </p>
          <Link
            href="/shop"
            className="inline-block rounded-[20px] bg-charcoal px-6 py-3 text-body font-regular text-snow hover:opacity-90 transition-opacity no-underline"
          >
            {t("backToNursery")}
          </Link>
        </div>
      </>
    );
  }

  return (
    <>
      <InnerNav />
      <main className="w-[98%] max-w-[2000px] mx-auto px-6 py-12">
        <Link
          href="/shop"
          className="inline-block text-body-sm font-regular text-charcoal/50 hover:text-charcoal transition-colors no-underline mb-8"
        >
          &larr; {t("backToNursery")}
        </Link>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-12 md:gap-16">
          <div className="relative aspect-[4/3] overflow-hidden rounded-[20px] bg-paper">
            {product.image ? (
              <Image
                src={product.image}
                alt={product.title}
                fill
                className="object-cover"
                sizes="(max-width: 768px) 100vw, 50vw"
                priority
              />
            ) : (
              <div className="absolute inset-0 flex items-center justify-center bg-charcoal/5">
                <span className="text-caption font-regular text-charcoal/30 uppercase tracking-[-0.06px]">
                  {t("noImage")}
                </span>
              </div>
            )}
          </div>

          <div className="flex flex-col justify-center">
            {product.category?.title && (
              <p className="text-caption font-regular text-charcoal/50 uppercase tracking-[-0.06px] mb-2">
                {product.category.title}
              </p>
            )}

            <h1 className="text-heading-lg md:text-display font-light text-charcoal leading-[0.95] tracking-[-0.8px] mb-3">
              {product.title}
            </h1>

            <p className="text-heading font-light text-charcoal leading-[1.07] tracking-[-0.42px] mb-1">
              ${product.price}
            </p>

            <StatusLabel status={product.status} t={t} />

            {product.description && (
              <p className="text-body font-light text-charcoal leading-[1.29] mt-6 max-w-[65ch]">
                {product.description}
              </p>
            )}

            <p className="text-body-sm font-light text-charcoal/40 mt-4">
              {product.stock > 0
                ? t("available", { count: product.stock })
                : product.status === "PREORDER"
                  ? t("limitedQty")
                  : t("currentlyUnavailable")}
            </p>

            {product.status === "OUT_OF_STOCK" ? (
              <div className="mt-8">
                <button
                  disabled
                  className="rounded-[20px] bg-charcoal/10 px-6 py-3 text-body font-regular text-charcoal/30 cursor-not-allowed"
                >
                  {t("soldOut")}
                </button>
              </div>
            ) : orderSuccess ? (
              <div className="mt-8 rounded-2xl bg-pine/5 border border-pine/20 p-6">
                <p className="text-heading-sm font-light text-pine mb-2">
                  ✓ {t("orderReceived")}
                </p>
                <p className="text-body-sm font-light text-charcoal/70">
                  {t("orderWillContact")}
                </p>
              </div>
            ) : showOrderForm ? (
              <form
                onSubmit={async (e) => {
                  e.preventDefault();
                  if (!product) return;
                  setOrderSubmitting(true);
                  setOrderError("");
                  try {
                    const payload: OrderCreatePayload = {
                      guest_name: orderForm.guest_name,
                      guest_phone: orderForm.guest_phone,
                      items: [{ product_id: product.id, quantity: 1 }],
                    };
                    await createOrder(payload);
                    setOrderSuccess(true);
                    setShowOrderForm(false);
                  } catch {
                    setOrderError(t("orderError"));
                  } finally {
                    setOrderSubmitting(false);
                  }
                }}
                className="mt-8 space-y-4 max-w-[360px]"
              >
                <div>
                  <label className="text-caption font-regular text-charcoal/60 uppercase block mb-1">
                    {t("yourName")}
                  </label>
                  <input
                    type="text"
                    required
                    value={orderForm.guest_name}
                    onChange={(e) =>
                      setOrderForm((prev) => ({ ...prev, guest_name: e.target.value }))
                    }
                    className="w-full text-body font-light text-charcoal border-b border-charcoal/30 bg-transparent outline-none py-1 focus:border-charcoal transition-colors"
                  />
                </div>
                <div>
                  <label className="text-caption font-regular text-charcoal/60 uppercase block mb-1">
                    {t("yourPhone")}
                  </label>
                  <input
                    type="tel"
                    required
                    value={orderForm.guest_phone}
                    onChange={(e) =>
                      setOrderForm((prev) => ({ ...prev, guest_phone: e.target.value }))
                    }
                    className="w-full text-body font-light text-charcoal border-b border-charcoal/30 bg-transparent outline-none py-1 focus:border-charcoal transition-colors"
                  />
                </div>
                {orderError && (
                  <p className="text-body-sm text-ember">{orderError}</p>
                )}
                <div className="flex gap-4 pt-2">
                  <CTAButton
                    type="submit"
                    label={orderSubmitting ? "…" : (product.status === "PREORDER" ? t("preorder") : t("addToCart"))}
                  />
                  <button
                    type="button"
                    onClick={() => setShowOrderForm(false)}
                    className="rounded-[20px] border border-charcoal/30 px-6 py-3 text-body font-regular text-charcoal hover:bg-charcoal/5 transition-colors"
                  >
                    {t("cancel")}
                  </button>
                </div>
              </form>
            ) : (
              <div className="mt-8">
                <CTAButton
                  label={
                    product.status === "PREORDER"
                      ? t("preorder")
                      : t("addToCart")
                  }
                  onClick={() => setShowOrderForm(true)}
                />
              </div>
            )}
          </div>
        </div>
      </main>
    </>
  );
}