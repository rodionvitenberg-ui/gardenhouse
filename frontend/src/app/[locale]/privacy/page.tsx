"use client";

import { useTranslations } from "next-intl";
import InnerNav from "@/components/InnerNav";

const sections = [
  { title: "section1Title", texts: ["section1Text1", "section1Text2", "section1Text3"] },
  { title: "section2Title", texts: ["section2Text1", "section2Text2"] },
  { title: "section3Title", texts: ["section3Text"] },
  { title: "section4Title", texts: ["section4Text"] },
  { title: "section5Title", texts: ["section5Text"] },
] as const;

export default function PrivacyPage() {
  const t = useTranslations("privacy");

  return (
    <>
      <InnerNav />
      <main className="w-[98%] max-w-[2000px] mx-auto px-6 pt-4 md:pt-12 pb-24">
        <div className="max-w-[720px] mx-auto">
          {/* Header */}
          <p className="text-caption font-regular text-charcoal/40 uppercase tracking-[-0.06px] mb-3">
            {t("lastUpdated")}
          </p>
          <h1 className="text-heading-lg md:text-display font-light text-charcoal leading-[0.95] tracking-[-0.8px] mb-8">
            {t("title")}
          </h1>

          {/* Intro */}
          <p className="text-body font-light text-charcoal/75 leading-[1.29] mb-4">
            {t("intro1")}
          </p>
          <p className="text-body font-light text-charcoal/75 leading-[1.29] mb-12">
            {t("intro2")}
          </p>

          {/* Sections */}
          {sections.map((section) => (
            <section key={section.title} className="mb-10">
              <h2 className="text-heading-sm font-light text-charcoal leading-[1.15] tracking-[-0.33px] mb-4">
                {t(section.title)}
              </h2>
              {section.texts.map((textKey, i) => (
                <p
                  key={`${section.title}-${i}`}
                  className="text-body font-light text-charcoal/75 leading-[1.29] mb-3 last:mb-0"
                >
                  {t(textKey)}
                </p>
              ))}
            </section>
          ))}

          {/* Outro */}
          <div className="mt-16 pt-8 border-t border-charcoal/10">
            <p className="text-body font-light text-charcoal/60 leading-[1.29] italic">
              {t("outro")}
            </p>
          </div>
        </div>
      </main>
    </>
  );
}