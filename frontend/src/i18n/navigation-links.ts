import type { useTranslations } from "next-intl";

/** Deep module — single source of truth for navigation links.
 *  All 4 navigation components (page.tsx, PrimaryNavigation, InnerNav, MobileMenuVariantB)
 *  import from here. Delete this module and nav breaks everywhere — that's depth. */
export function getNavLinks(
  t: ReturnType<typeof useTranslations<"nav">>
): { label: string; href: string }[] {
  return [
    { label: t("shop"), href: "/shop" },
    { label: t("house"), href: "/house" },
    { label: t("about"), href: "/about-prototype" },
    { label: t("journal"), href: "/journal" },
    { label: t("contact"), href: "/contact" },
  ];
}