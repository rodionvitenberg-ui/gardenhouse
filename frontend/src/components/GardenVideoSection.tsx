'use client';

import { useRef, useEffect } from 'react';
import { useTranslations } from 'next-intl';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import Link from 'next/link';

gsap.registerPlugin(ScrollTrigger);

const videoSrc = '/13704-250154065_medium.mp4';

const paragraphKeys = [
  'paragraph1',
  'paragraph2',
  'paragraph3',
  'paragraph4',
] as const;

export default function GardenVideoSection() {
  const t = useTranslations('gardenVideo');
  const sectionRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      gsap.utils.toArray<HTMLElement>('.gvs-paragraph').forEach((p) => {
        gsap.fromTo(
          p,
          { opacity: 0, y: 40 },
          {
            opacity: 1,
            y: 0,
            duration: 0.9,
            ease: 'power3.out',
            scrollTrigger: {
              trigger: p,
              start: 'top 85%',
              once: true,
            },
          },
        );
      });
    }, sectionRef);
    return () => ctx.revert();
  }, []);

  return (
    <section ref={sectionRef} className="relative bg-charcoal">
      {/* Full-bleed sticky video — на всё окно */}
      <div className="sticky top-0 h-[100dvh] w-full overflow-hidden">
        <video
          className="absolute inset-0 w-full h-full object-cover"
          src={videoSrc}
          muted
          autoPlay
          loop
          playsInline
          preload="none"
        />
        <div className="absolute inset-0 bg-charcoal/50 md:bg-charcoal/30" />

        {/* Desktop: текст + CTA прибиты к нижнему левому углу ВНУТРИ sticky-контейнера */}
        <div className="hidden md:block absolute bottom-12 left-0 w-full px-16 z-10">
          <p className="text-subheading font-light text-snow/70 leading-[1.4] mb-6 tracking-[-0.01em] max-w-[480px]">
            {t('hero')}
          </p>
          <Link
            href="/booking"
            className="inline-flex items-center gap-1 rounded-[99px] border-2 border-snow px-5 py-3 text-body font-regular text-snow no-underline hover:bg-snow hover:text-charcoal transition-colors"
          >
            {t('ctaLabel')} <span>→</span>
          </Link>
        </div>
      </div>

      {/* Content scrolls over video */}
      <div className="relative z-10 flex flex-col -mt-[100dvh]">
        {/* ===== MOBILE ===== */}
        <div className="md:hidden px-6">
          {/* First screen: teaser + CTA */}
          <div className="min-h-[100dvh] flex flex-col justify-end pb-12 pt-24">
            <p className="text-[18px] font-light text-snow/90 leading-[1.4] mb-0 tracking-[-0.01em]">
              {t('hero')}
            </p>
            <div>
              <Link
                href="/booking"
                className="inline-flex items-center mb-60 gap-1 rounded-[99px] border-2 border-snow px-5 py-3 text-body font-regular text-snow no-underline hover:bg-snow hover:text-charcoal transition-colors"
              >
                {t('ctaLabel')} <span>→</span>
              </Link>
            </div>
          </div>

          {/* Paragraphs */}
          <div className="flex flex-col gap-32 pb-32 pt-12">
            {paragraphKeys.map((key) => (
              <p
                key={key}
                className="gvs-paragraph text-[28px] font-light text-snow/90 leading-[1.25] tracking-[-0.02em]"
              >
                {t(key)}
              </p>
            ))}
          </div>
        </div>

        {/* ===== DESKTOP ===== */}
        <div className="hidden md:block">
          {/* Пустой экран, чтобы контент начинался после первого viewport */}
          <div className="h-screen" />

          {/* Paragraphs — right-aligned, scrolling over full-width video */}
          <div className="w-[98%] max-w-[2000px] mx-auto px-6 pb-32">
            <div className="max-w-[600px] ml-auto flex flex-col gap-32">
              {paragraphKeys.map((key) => (
                <p
                  key={key}
                  className="gvs-paragraph text-[40px] md:text-[48px] font-light text-snow/85 leading-[1.15] tracking-[-0.02em]"
                >
                  {t(key)}
                </p>
              ))}
            </div>
          </div>

          {/* Заглушка — 500px пустого пространства */}
          <div className="h-[500px]" />
        </div>
      </div>
    </section>
  );
}