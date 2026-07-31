"use client";

import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import InnerNav from "@/components/InnerNav";
import CTAButton from "@/components/CTAButton";
import AmbientVideo from "@/components/AmbientVideo";

const momentKeys = [
  { time: "momentArrivalTime", text: "momentArrivalText" },
  { time: "momentMorningTime", text: "momentMorningText" },
  { time: "momentAfternoonTime", text: "momentAfternoonText" },
  { time: "momentEveningTime", text: "momentEveningText" },
] as const;

const detailKeys = [
  { label: "detailFor", value: "detailGuests" },
  { label: "detailSeason", value: "detailSeasonValue" },
  { label: "detailRate", value: "detailRateValue" },
] as const;

/** Разные видео для каждого блока */
const videos = [
  { src: "/188912-884171167_medium.mp4", poster: "/188912-884171167_medium-poster.jpg" },
  { src: "/203923-922675870_medium.mp4", poster: "/203923-922675870_medium-poster.jpg" },
  { src: "/23881-337972830_medium.mp4", poster: "/23881-337972830_medium-poster.jpg" },
  { src: "/13704-250154065_medium.mp4", poster: "/13704-poster.jpg" },
  { src: "/132932-755272963_medium.mp4", poster: "/132932-755272963_medium-poster.jpg" },
  { src: "/174860-852215326_medium.mp4", poster: "/174860-852215326_medium-poster.jpg" },
];

export default function HousesPageClient() {
  const t = useTranslations("house");

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
              overlayClassName="bg-charcoal/25"
              playIconSize="w-16 h-16"
              className="absolute inset-0"
            />
            <div className="absolute bottom-0 left-0 right-0 p-8 md:p-10 z-10 pointer-events-none">
              <p className="text-caption font-regular text-snow/70 uppercase tracking-[-0.06px] mb-4">
                Father's Garden
              </p>
              <h1 className="text-heading-lg md:text-display font-light text-snow leading-[0.95] tracking-[-0.8px] mb-6 max-w-[600px]">
                {t("title")}
              </h1>
              <p className="text-subheading font-light text-snow/80 leading-[1.22] max-w-[420px] mb-8">
                {t("heroSubtext")}
              </p>
              <div className="pointer-events-auto">
                <Link href="/booking" className="no-underline">
                  <CTAButton label={t("bookNow")} />
                </Link>
              </div>
            </div>
          </div>
        </section>

        {/* ── Moments ── */}
        {momentKeys.map((moment, i) => (
          <section
            key={moment.time}
            className={`px-6 py-12 md:py-20 flex flex-col ${
              i % 2 === 0 ? "md:flex-row" : "md:flex-row-reverse"
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
              <div className="absolute bottom-2 left-0 right-0 p-6 md:hidden z-10 pointer-events-none">
                <p className="text-caption font-regular text-snow/80 uppercase tracking-[-0.06px] mb-2">
                  {t(moment.time)}
                </p>
                <p className="text-subheading font-light text-snow/90 leading-[1.22]">
                  {t(moment.text)}
                </p>
              </div>
            </div>
            <div className="hidden md:block w-1/2 max-w-[400px]">
              <p className="text-caption font-regular text-charcoal/30 uppercase tracking-[-0.06px] mb-3">
                {t(moment.time)}
              </p>
              <p className="text-heading font-light text-charcoal leading-[1.07] tracking-[-0.42px]">
                {t(moment.text)}
              </p>
            </div>
          </section>
        ))}

        {/* ── Details ── */}
        <section className="px-6 py-16 md:py-24 text-center sm:text-left">
          <div className="max-w-[720px] mx-auto grid grid-cols-1 sm:grid-cols-3 gap-8">
            {detailKeys.map((item) => (
              <div key={item.label}>
                <p className="text-caption font-regular text-charcoal/30 uppercase tracking-[-0.06px] mb-1">
                  {t(item.label)}
                </p>
                <p className="text-heading-sm font-light text-charcoal leading-[1.15] tracking-[-0.33px]">
                  {t(item.value)}
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
            <p className="text-heading font-light text-snow/90 leading-[1.07] tracking-[-0.42px] max-w-[500px]">
              {t("closingText")}
            </p>
          </div>
        </section>

        {/* ── CTA ── */}
        <section className="px-6 pb-24 md:py-32 text-center md:min-h-[35dvh] md:flex md:items-center md:justify-center">
          <div>
            <p className="text-heading font-light text-charcoal leading-[1.07] tracking-[-0.42px] mb-4">
              {t("ctaTitle")}
            </p>
            <p className="text-body font-light text-charcoal/50 mb-8">
              {t("ctaSubtext")}
            </p>
            <Link href="/booking" className="no-underline">
              <CTAButton label={t("bookNow")} />
            </Link>
          </div>
        </section>
      </main>
    </>
  );
}