"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import Image from "next/image";
import { fetchCategories } from "@/lib/api";
import type { Category } from "@/types";

export default function Footer() {
  const t = useTranslations("footer");
  const [categories, setCategories] = useState<Category[]>([]);

  useEffect(() => {
    fetchCategories().then(setCategories).catch(() => {});
  }, []);

  const footerSections = [
    {
      title: t("shop"),
      links: [
        { label: t("allProducts"), href: "/shop" },
        ...categories.slice(0, 3).map((cat) => ({
          label: cat.title,
          href: `/shop?category=${cat.slug}`,
        })),
      ],
    },
    {
      title: t("stay"),
      links: [
        { label: t("ourHouse"), href: "/house" },
        { label: t("bookingInfo"), href: "/house#info" },
        { label: t("gallery"), href: "/gallery" },
      ],
    },
    {
      title: t("journal"),
      links: [
        { label: t("gardenNotes"), href: "/journal" },
        { label: t("seasonalTips"), href: "/journal#tips" },
        { label: t("guestStories"), href: "/journal#stories" },
      ],
    },
    {
      title: t("info"),
      links: [
        { label: t("aboutUs"), href: "/about-prototype" },
        { label: t("contact"), href: "/contact" },
        { label: t("privacy"), href: "/privacy" },
      ],
    },
  ];

  return (
    <footer className="px-6 py-12 w-[98%] max-w-[2000px] mx-auto">
      <div className="mb-10">
        <Link href="/" className="block no-underline">
          <Image
            src="/logo2.png"
            alt="GardenHouse"
            width={800}
            height={180}
            className="h-21 w-auto object-contain"
            priority
          />
        </Link>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-8">
        {footerSections.map((section) => (
          <div key={section.title}>
            <h4 className="text-nav font-helvetica-condensed font-black text-charcoal/80 uppercase tracking-[0.04em] mb-4">
              {section.title}
            </h4>
            <ul className="space-y-3">
              {section.links.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-body-sm font-regular text-charcoal no-underline"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>

      <div className="mt-16 pt-8 border-t border-charcoal/10">
        <p className="text-caption text-charcoal/60">
          {t("copyright", { year: new Date().getFullYear() })}
        </p>
      </div>
    </footer>
  );
}