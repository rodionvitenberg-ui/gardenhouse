'use client';

import Image from 'next/image';
import Link from 'next/link';
import type { Category } from '@/types';

interface NurseryCarouselProps {
  categories: Category[];
}

/**
 * Горизонтальная карусель категорий питомника.
 * Только естественный скролл — на десктопе колёсиком/трекпадом, на мобильных touch.
 */
export default function NurseryCarousel({ categories }: NurseryCarouselProps) {
  const cardWidth = 360;

  return (
    <div className="flex gap-8 overflow-x-auto scrollbar-none" style={{ WebkitOverflowScrolling: 'touch' }}>
      {categories.length === 0
        ? Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="shrink-0 space-y-4" style={{ width: `${cardWidth}px` }}>
              <div className="aspect-[4/5] rounded-[20px] bg-charcoal/5 animate-pulse" />
              <div className="h-5 w-32 bg-charcoal/5 animate-pulse rounded" />
            </div>
          ))
        : categories.map((cat) => (
            <Link
              key={cat.id}
              href={`/shop?category=${cat.slug}`}
              className="block shrink-0 no-underline group"
              style={{ width: `${cardWidth}px` }}
            >
              <div className="relative aspect-[4/5] overflow-hidden rounded-[20px] bg-paper mb-4">
                {cat.image ? (
                  <Image
                    src={cat.image}
                    alt={cat.title}
                    fill
                    className="object-cover group-hover:scale-[1.03] transition-transform duration-700 ease-out"
                    sizes="360px"
                  />
                ) : (
                  <div className="absolute inset-0 flex items-center justify-center bg-charcoal/5">
                    <span className="text-caption font-regular text-charcoal/20 uppercase tracking-[-0.06px]">
                      No image
                    </span>
                  </div>
                )}
              </div>
              <p className="text-subheading font-light text-charcoal leading-[1.22]">
                {cat.title}
              </p>
            </Link>
          ))}
    </div>
  );
}