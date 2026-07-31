"use client";

import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import InnerNav from "@/components/InnerNav";
import AmbientVideo from "@/components/AmbientVideo";

const chapterIds = [
  "chapter1",
  "chapter2",
  "chapter3",
  "chapter4",
] as const;

const statIds = [
  { label: "statStarted", value: "statStartedValue" },
  { label: "statLocation", value: "statLocationValue" },
  { label: "statNow", value: "statNowValue" },
] as const;

/** Каждому блоку — своё видео для разнообразия */
const videos = [
  { src: "/287510_medium.mp4", poster: "/287510_medium-poster.jpg" },
  { src: "/354006_medium.mp4", poster: "/354006_medium-poster.jpg" },
  { src: "/14838732_2160_3840_24fps.mp4", poster: "/14838732_2160_3840_24fps-poster.jpg" },
  { src: "/14949894_2160_3840_30fps.mp4", poster: "/14949894_2160_3840_30fps-poster.jpg" },
  { src: "/132932-755272963_medium.mp4", poster: "/132932-755272963_medium-poster.jpg" },
  { src: "/174860-852215326_medium.mp4", poster: "/174860-852215326_medium-poster.jpg" },
];

export default function AboutPrototypePage() {
  const t = useTranslations("about");

  return (
    <>
      <InnerNav />
      <main className="w-[98%] max-w-[2000px] mx-auto pb-24">
        {/* ── Hero ── */}
        <section className="relative min-h-[85dvh] px-6">
          <div className="absolute left-6 right-6 top-0 bottom-[2dvh] rounded-[40px] overflow-hidden">
            <AmbientVideo
              src={videos[0].src}
              poster={videos[0].poster}
              aspectRatio="aspect-[4/3]"
              rounded="rounded-[40px]"
              overlayClassName="bg-charcoal/30"
              playIconSize="w-16 h-16"
              className="absolute inset-0"
            />
            <div className="absolute bottom-0 left-0 right-0 p-8 md:p-10 z-10 pointer-events-none">
              <p className="text-caption font-regular text-snow/70 uppercase tracking-[-0.06px] mb-4">
                {t("location")}
              </p>
              <h1 className="text-heading-lg md:text-display font-light text-snow leading-[0.95] tracking-[-0.8px] mb-6 max-w-[600px]">
                {t("heroTitle")}
              </h1>
              <p className="text-subheading font-light text-snow/80 leading-[1.22] max-w-[420px] mb-8">
                {t("heroSubtext")}
              </p>
            </div>
          </div>
        </section>

        {/* ── Chapters ── */}
        {chapterIds.map((id, i) => (
          <section
            key={id}
            className={`px-6 py-12 md:py-20 flex flex-col ${
              i % 2 === 0 ? "md:flex-row-reverse" : "md:flex-row"
            } gap-8 md:gap-16 items-center`}
          >
            <div className="relative w-full md:w-1/2 overflow-hidden rounded-[40px] aspect-[3/4] md:aspect-[4/3]">
              <AmbientVideo
                src={videos[i + 1].src}
                poster={videos[i + 1].poster}
                aspectRatio="aspect-[3/4] md:aspect-[4/3]"
                rounded="rounded-[40px]"
                overlayClassName="bg-charcoal/20"
                playIconSize="w-12 h-12"
              />

              {/* Mobile overlay text */}
              <div
                className={`md:hidden absolute left-0 right-0 pl-8 pr-6 pt-6 pb-6 z-10 pointer-events-none ${
                  i % 2 === 0 ? "top-0" : "bottom-0"
                }`}
              >
                <span className="text-[40px] font-light text-snow/80 leading-[0.85] tracking-[-0.03em] select-none block mb-3">
                  {t(`${id}Year`)}
                </span>
                <p className="text-heading-lg font-light text-snow leading-[0.95] tracking-[-0.8px] mb-4">
                  {t(`${id}Title`)}
                </p>
                <p className="text-subheading font-light text-snow/80 leading-[1.22] tracking-[-0.18px]">
                  {t(`${id}Text`)}
                </p>
              </div>
            </div>

            <div className="hidden md:block w-full md:w-1/2 max-w-[400px]">
              <span className="text-[96px] font-light text-charcoal/10 leading-[0.85] tracking-[-0.03em] select-none block mb-2">
                {t(`${id}Year`)}
              </span>
              <p className="text-heading font-light text-charcoal leading-[1.07] tracking-[-0.42px] mb-5">
                {t(`${id}Title`)}
              </p>
              <p className="text-body font-light text-charcoal/65 leading-[1.29]">
                {t(`${id}Text`)}
              </p>
            </div>
          </section>
        ))}

        {/* ── Stats ── */}
        <section className="px-6 py-16 md:py-24 text-center sm:text-left">
          <div className="max-w-[720px] mx-auto grid grid-cols-1 sm:grid-cols-3 gap-8">
            {statIds.map((stat) => (
              <div key={stat.label}>
                <p className="text-caption font-regular text-charcoal/30 uppercase tracking-[-0.06px] mb-1">
                  {t(stat.label)}
                </p>
                <p className="text-heading-sm font-light text-charcoal leading-[1.15] tracking-[-0.33px]">
                  {t(stat.value)}
                </p>
              </div>
            ))}
          </div>
        </section>

        {/* ── Closing ── */}
        <section className="relative mx-6 mb-16 overflow-hidden rounded-[40px]">
          <AmbientVideo
            src={videos[5].src}
            poster={videos[5].poster}
            aspectRatio="aspect-[3/4] md:aspect-[21/9]"
            rounded="rounded-[40px]"
            overlayClassName="bg-charcoal/30"
            playIconSize="w-16 h-16"
          />
          <div className="absolute bottom-2 left-0 right-0 p-6 md:p-12 z-10 pointer-events-none">
            <p className="text-heading font-light text-snow/90 leading-[1.07] tracking-[-0.42px] max-w-[500px] mb-6">
              {t("closingText")}
            </p>
            <Link
              href="/booking"
              className="inline-block rounded-[20px] bg-charcoal px-6 py-3 text-body font-regular text-snow hover:opacity-90 transition-opacity pointer-events-auto"
            >
              {t("bookHouse")}
            </Link>
          </div>
        </section>
      </main>
    </>
  );
}