"use client";

import { Suspense, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import HeroVariantA from "@/components/HeroVariantA";
import GardenVideoSection from "@/components/GardenVideoSection";
import NurseryCarousel from "@/components/NurseryCarousel";
import HouseTeaser from "@/components/HouseTeaser";
import PillLinkButton from "@/components/PillLinkButton";
import MobileMenuVariantB from "@/components/MobileMenuVariantB";
import { getNavLinks } from "@/i18n/navigation-links";
import { fetchCategories, fetchHouses } from "@/lib/api";
import type { Category, House } from "@/types";

function HomePageContent() {
  const t = useTranslations();
  const navT = useTranslations("nav");
  const navLinks = getNavLinks(navT);
  const [categories, setCategories] = useState<Category[]>([]);
  const [houses, setHouses] = useState<House[]>([]);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    fetchCategories().then(setCategories).catch(() => {});
    fetchHouses().then(setHouses).catch(() => {});
  }, []);

  return (
    <>
      {/* ─────── HERO — full-bleed ─────── */}
      <HeroVariantA
        menuOpen={menuOpen}
        onMenuToggle={() => setMenuOpen(!menuOpen)}
        navLinks={navLinks}
      />

      {/* ─────── GARDEN VIDEO ─────── */}
      <GardenVideoSection />

      {/* ─────── CONTENT ─────── */}
      <div className="w-[98%] max-w-[2000px] mx-auto px-6">
        {/* ── From the nursery ── */}
        <section className="mt-20 mb-28">
          <div className="flex items-center justify-between mb-10">
            <h2 className="text-heading font-light text-charcoal tracking-[-0.02em]">
              {t("sections.nursery")}
            </h2>
            <PillLinkButton href="/shop" label={t("sections.viewAllPlants")} />
          </div>
          <NurseryCarousel categories={categories} />
        </section>

        {/* ── Stay with us ── */}
        <section className="mb-28">
          <div className="flex items-center justify-between mb-10">
            <h2 className="text-heading font-light text-charcoal tracking-[-0.02em]">
              {t("sections.stay")}
            </h2>
          </div>
          <HouseTeaser houses={houses} />
        </section>
      </div>

      {/* ─────── MOBILE MENU ─────── */}
      <MobileMenuVariantB
        open={menuOpen}
        onClose={() => setMenuOpen(false)}
        navLinks={navLinks}
      />
    </>
  );
}

export default function HomePage() {
  return (
    <Suspense fallback={null}>
      <HomePageContent />
    </Suspense>
  );
}