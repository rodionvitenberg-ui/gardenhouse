"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import Image from "next/image";
import InnerNav from "@/components/InnerNav";
import { fetchGalleryImages } from "@/lib/api";
import type { GalleryImage } from "@/types";

function ImageCard({ image }: { image: GalleryImage }) {
  const t = useTranslations("gallery");
  const caption = image.caption || image.alt || "";
  const alt = image.alt || `Gallery photo — ${image.category}`;

  return (
    <div className="group">
      <div className="relative aspect-[4/3] overflow-hidden rounded-[20px] bg-paper">
        <Image
          src={image.image}
          alt={alt}
          fill
          className="object-cover transition-transform duration-500 ease-out group-hover:scale-[1.03]"
          sizes="(max-width: 768px) 100vw, 50vw"
        />
      </div>
      {caption && (
        <div className="mt-4">
          <p className="text-caption font-regular text-charcoal uppercase tracking-[-0.06px]">
            {caption}
          </p>
        </div>
      )}
    </div>
  );
}

export default function GalleryClient() {
  const t = useTranslations("gallery");
  const [images, setImages] = useState<GalleryImage[]>([]);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    fetchGalleryImages()
      .then((imgs) => {
        setImages(imgs);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  return (
    <>
      <InnerNav />
      <div className="w-[98%] max-w-[2000px] mx-auto px-6 pt-6 md:pt-12 pb-24">
        {/* Header */}
        <div className="mb-12 md:mb-20">
          <h1 className="text-heading-lg md:text-display font-light text-charcoal leading-[0.95] tracking-[-0.02em] max-w-[600px]">
            {t("title")}
          </h1>
          <p className="text-subheading font-light text-charcoal leading-[1.22] max-w-[480px] mt-4">
            {t("subtitle")}
          </p>
        </div>

        {/* Loading state */}
        {loading && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 md:gap-8">
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i}>
                <div className="aspect-[4/3] rounded-[20px] bg-charcoal/5 animate-pulse" />
                <div className="mt-4 space-y-2">
                  <div className="h-3 w-24 bg-charcoal/5 animate-pulse rounded" />
                  <div className="h-4 w-20 bg-charcoal/5 animate-pulse rounded" />
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Empty state */}
        {!loading && images.length === 0 && (
          <div className="text-center py-24">
            <p className="text-subheading font-light text-charcoal/60">
              {t("empty")}
            </p>
          </div>
        )}

        {/* Gallery grid */}
        {!loading && images.length > 0 && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 md:gap-8">
            {images.map((image) => (
              <ImageCard
                key={image.id}
                image={image}
              />
            ))}
          </div>
        )}
      </div>
    </>
  );
}