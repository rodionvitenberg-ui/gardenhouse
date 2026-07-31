"use client";

import { useTranslations } from "next-intl";
import InnerNav from "@/components/InnerNav";

const contactMethods = [
  { label: "methodWrite", value: "methodWriteValue", detail: "methodWriteDetail" },
  { label: "methodCall", value: "methodCallValue", detail: "methodCallDetail" },
  { label: "methodVisit", value: "methodVisitValue", detail: "methodVisitDetail" },
] as const;

export default function ContactPage() {
  const t = useTranslations("contact");

  return (
    <>
      <InnerNav />
      <main className="w-[98%] max-w-[2000px] mx-auto">
        <section className="px-6 pt-4 md:pt-8 pb-12 md:pb-20">
          <h1 className="text-display font-light text-charcoal leading-[0.95] tracking-[-0.8px] max-w-4xl mb-8">
            {t("getInTouch")}
          </h1>
          <p className="text-subheading md:text-[20px] font-light text-charcoal/45 leading-[1.22] tracking-[-0.18px] max-w-[520px]">
            {t("heroText")}
          </p>
        </section>

        <section className="px-6 pb-16 md:pb-24">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-10 md:gap-16">
            {contactMethods.map((item) => (
              <div key={item.label}>
                <p className="text-caption font-regular text-charcoal/25 uppercase tracking-[-0.06px] mb-2">
                  {t(item.label)}
                </p>
                <p className="text-heading-sm font-light text-charcoal leading-[1.15] tracking-[-0.33px] mb-1">
                  {t(item.value)}
                </p>
                <p className="text-body-sm font-light text-charcoal/40 leading-[1.33]">
                  {t(item.detail)}
                </p>
              </div>
            ))}
          </div>
        </section>

        <section className="px-6 pb-24 md:pb-40">
          <div className="w-full h-px bg-charcoal/8 mb-16" />
          <div className="max-w-[480px]">
            <p className="text-heading-sm font-light text-charcoal leading-[1.15] tracking-[-0.33px] mb-1">
              {t("sendMessage")}
            </p>
            <p className="text-caption font-regular text-charcoal/35 uppercase tracking-[-0.06px] mb-8">
              {t("orSayHello")}
            </p>
            <form className="space-y-5" onSubmit={(e) => e.preventDefault()}>
              <div>
                <label className="block text-caption font-regular text-charcoal/40 uppercase tracking-[-0.06px] mb-2">
                  {t("name")}
                </label>
                <input
                  type="text"
                  placeholder={t("placeholderName")}
                  className="w-full border-b border-charcoal/15 bg-transparent pb-2 text-body font-light text-charcoal placeholder:text-charcoal/25 outline-none focus:border-charcoal/40 transition-colors"
                />
              </div>
              <div>
                <label className="block text-caption font-regular text-charcoal/40 uppercase tracking-[-0.06px] mb-2">
                  {t("email")}
                </label>
                <input
                  type="email"
                  placeholder={t("placeholderEmail")}
                  className="w-full border-b border-charcoal/15 bg-transparent pb-2 text-body font-light text-charcoal placeholder:text-charcoal/25 outline-none focus:border-charcoal/40 transition-colors"
                />
              </div>
              <div>
                <label className="block text-caption font-regular text-charcoal/40 uppercase tracking-[-0.06px] mb-2">
                  {t("message")}
                </label>
                <textarea
                  rows={4}
                  placeholder={t("placeholderMessage")}
                  className="w-full border-b border-charcoal/15 bg-transparent pb-2 text-body font-light text-charcoal placeholder:text-charcoal/25 outline-none focus:border-charcoal/40 transition-colors resize-none"
                />
              </div>
              <button
                type="submit"
                className="rounded-[20px] bg-charcoal px-8 py-3 text-body font-regular text-snow hover:opacity-90 transition-opacity active:scale-[0.98]"
              >
                {t("sendAction")}
              </button>
            </form>
          </div>
        </section>

      </main>
    </>
  );
}