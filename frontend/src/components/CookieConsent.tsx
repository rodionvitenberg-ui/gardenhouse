"use client";

import { useState, useEffect } from "react";
import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";

const COOKIE_CONSENT_KEY = "fg_cookie_consent";

type ConsentChoice = "accepted" | "declined" | null;

export default function CookieConsent() {
  const t = useTranslations("cookieConsent");
  const [consent, setConsent] = useState<ConsentChoice>(null);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
    const stored = localStorage.getItem(COOKIE_CONSENT_KEY) as ConsentChoice;
    if (!stored) {
      setConsent(null);
    } else {
      setConsent(stored);
    }
  }, []);

  function handleAccept() {
    localStorage.setItem(COOKIE_CONSENT_KEY, "accepted");
    setConsent("accepted");
  }

  function handleDecline() {
    localStorage.setItem(COOKIE_CONSENT_KEY, "declined");
    setConsent("declined");
  }

  if (!mounted || consent !== null) return null;

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 p-4 md:p-6">
      <div className="mx-auto max-w-[1280px]">
        <div className="rounded-[20px] bg-charcoal px-6 py-5 md:px-8 md:py-6 shadow-lg flex flex-col md:flex-row items-start md:items-center gap-4 md:gap-6">
          <p className="text-body-sm font-regular text-snow leading-[1.33] flex-1">
            {t("text")}
          </p>

          <div className="flex items-center gap-3 shrink-0">
            <Link
              href="/privacy"
              className="text-body-sm font-regular text-snow/60 underline underline-offset-2 hover:text-snow transition-colors no-underline"
            >
              {t("learnMore")}
            </Link>

            <button
              onClick={handleDecline}
              className="rounded-[20px] border-2 border-snow/30 px-5 py-2 text-body-sm font-regular text-snow hover:bg-snow/10 transition-colors"
            >
              {t("decline")}
            </button>

            <button
              onClick={handleAccept}
              className="rounded-[20px] bg-marigold px-5 py-2 text-body-sm font-regular text-charcoal hover:bg-marigold/90 transition-colors"
            >
              {t("accept")}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}