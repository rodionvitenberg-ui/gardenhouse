"use client";

import { useLocale } from "next-intl";
import { usePathname, useRouter } from "@/i18n/navigation";

const localeLabels: Record<string, string> = {
  en: "EN",
  ru: "RU",
};

interface Props {
  /** 'pill' = desktop style (border-2, 16px text), 'mobilePill' = mobile style (border, 14px text) */
  variant?: "pill" | "mobilePill";
  /** Font class override — e.g. 'font-helvetica-condensed' for the main nav */
  fontClass?: string;
}

export default function LocaleSwitcher({ variant = "pill", fontClass }: Props) {
  const locale = useLocale();
  const router = useRouter();
  const pathname = usePathname();

  const switchTo = locale === "en" ? "ru" : "en";

  const handleSwitch = () => {
    router.replace(pathname, { locale: switchTo });
  };

  const isDesktop = variant === "pill";

  return (
    <button
      onClick={handleSwitch}
      className={`flex items-center gap-0.5 rounded-[99px] ${
        isDesktop ? "border-2" : "border"
      } border-charcoal px-3 py-1.5 bg-transparent cursor-pointer hover:bg-charcoal/[0.04] transition-colors`}
      aria-label={`Switch to ${localeLabels[switchTo]}`}
    >
      <span
        className={`${fontClass || ""} ${
          locale === "en"
            ? isDesktop
              ? "text-nav font-helvetica-condensed text-charcoal"
              : "text-body-sm font-helvetica-condensed text-charcoal"
            : isDesktop
              ? "text-nav font-helvetica-condensed text-charcoal/50"
              : "text-body-sm font-helvetica-condensed text-charcoal/50"
        }`}
      >
        EN
      </span>
      <span className="mx-0.5 text-charcoal/40">|</span>
      <span
        className={`${fontClass || ""} ${
          locale === "ru"
            ? isDesktop
              ? "text-nav font-helvetica-condensed text-charcoal"
              : "text-body-sm font-helvetica-condensed text-charcoal"
            : isDesktop
              ? "text-nav font-helvetica-condensed text-charcoal/50"
              : "text-body-sm font-helvetica-condensed text-charcoal/50"
        }`}
      >
        RU
      </span>
    </button>
  );
}