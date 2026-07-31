"use client";

import Image from "next/image";
import { Link } from "@/i18n/navigation";
import { useTranslations } from "next-intl";
import SplitText from "@/components/SplitText";
import AmbientVideo from "@/components/AmbientVideo";
import MobileHeroVariantA from "@/components/MobileHeroVariantA";
import NavLink from "@/components/NavLink";
import LocaleSwitcher from "@/components/LocaleSwitcher";
import PillLinkButton from "@/components/PillLinkButton";

interface NavLinkData {
  href: string;
  label: string;
}

interface HeroVariantAProps {
  menuOpen: boolean;
  onMenuToggle: () => void;
  navLinks: NavLinkData[];
}

export default function HeroVariantA({ menuOpen, onMenuToggle, navLinks }: HeroVariantAProps) {
  const t = useTranslations();

  return (
    <section className="relative w-full md:h-[100dvh] min-h-[100dvh] flex flex-col md:overflow-hidden">
      <div className="absolute inset-0 bg-[#fdf9ed]" />

      {/* Navigation */}
      <div className="relative z-20 shrink-0">
        <nav className="flex items-center justify-between px-6 py-4 md:py-6 w-[98%] max-w-[2000px] mx-auto">
          <Link href="/" className="no-underline shrink-0 md:-ml-2">
            <Image
              src="/logo.png"
              alt={t("home.altLogo")}
              width={800}
              height={180}
              className="hidden md:block h-28 w-auto"
              priority
              fetchPriority="high"
            />
            <Image
              src="/logo1.png"
              alt={t("home.altLogo")}
              width={320}
              height={72}
              className="block md:hidden h-22 w-auto"
              priority
              fetchPriority="high"
            />
          </Link>

          <div className="hidden md:flex items-center gap-10">
            {navLinks.map((link) => (
              <NavLink
                key={link.href}
                href={link.href}
                label={link.label}
                className="text-nav font-helvetica-condensed font-black text-charcoal/90 uppercase tracking-[0.04em]"
              />
            ))}
            <div className="ml-2">
              <LocaleSwitcher />
            </div>
          </div>

          <div className="flex md:hidden items-center gap-1.5">
            <LocaleSwitcher variant="mobilePill" />
            <button
              onClick={onMenuToggle}
              className="flex flex-col gap-[6px] p-3 -mr-2 rounded-[12px] hover:bg-charcoal/5 active:bg-charcoal/10 transition-colors"
              aria-label={t("home.ariaToggleMenu")}
            >
              <span
                className={`block w-7 h-[2px] bg-charcoal rounded-sm transition-all duration-300 ease-[cubic-bezier(0.32,0.72,0,1)] origin-center ${
                  menuOpen ? "rotate-45 translate-y-[8px]" : ""
                }`}
              />
              <span
                className={`block w-7 h-[2px] bg-charcoal rounded-sm transition-all duration-300 ease-[cubic-bezier(0.32,0.72,0,1)] ${
                  menuOpen ? "opacity-0 scale-x-0" : ""
                }`}
              />
              <span
                className={`block w-7 h-[2px] bg-charcoal rounded-sm transition-all duration-300 ease-[cubic-bezier(0.32,0.72,0,1)] origin-center ${
                  menuOpen ? "-rotate-45 -translate-y-[8px]" : ""
                }`}
              />
            </button>
          </div>
        </nav>
      </div>

      {/* Hero body */}
      <div className="relative z-10 flex-1 min-h-0 flex flex-col md:flex-row w-[98%] max-w-[2000px] mx-auto">
        {/* Desktop hero: asymmetric split */}
        <div className="hidden md:flex flex-row w-full min-h-0">
          <div className="w-1/2 flex flex-col justify-start pt-10 md:pt-12 px-6 pb-6">
            <div className="max-w-[600px]">
              <SplitText
                text={t("hero.headline")}
                tag="h1"
                splitType="chars"
                textAlign="left"
                from={{ opacity: 0, y: 60 }}
                to={{ opacity: 1, y: 0 }}
                delay={35}
                duration={1.2}
                ease="power3.out"
                threshold={0}
                rootMargin="100px"
                className="text-[40px] md:text-[80px] font-light text-charcoal leading-[0.85] tracking-[-0.03em]"
                onLetterAnimationComplete={() => {}}
              />
              <SplitText
                text={t("hero.subhead")}
                tag="p"
                splitType="words"
                textAlign="left"
                from={{ opacity: 0, y: 30 }}
                to={{ opacity: 1, y: 0 }}
                delay={20}
                duration={1}
                ease="power3.out"
                threshold={0}
                rootMargin="100px"
                className="text-[20px] md:text-[28px] font-light text-charcoal/70 leading-[1.25] max-w-[480px] mt-6 tracking-[-0.01em]"
                onLetterAnimationComplete={() => {}}
              />

              {/* CTAs */}
              <div className="flex items-center gap-4 mt-8">
                <PillLinkButton href="/house" label={t("sections.viewAllHouses")} />
                <PillLinkButton href="/shop" label={t("sections.viewAllPlants")} />
              </div>
            </div>
          </div>

          <div className="flex flex-col w-3/5 gap-3 py-4 min-h-0">
            <div className="flex-[5] min-h-0 rounded-tl-[40px] overflow-hidden relative">
              <AmbientVideo
                src="/287510_medium.mp4"
                poster="/287510_medium-poster.jpg"
                aspectRatio="aspect-[4/3]"
                rounded="rounded-tl-[40px]"
                overlayClassName="bg-charcoal/15"
                playIconSize="w-14 h-14"
                className="absolute inset-0 w-full h-full"
              />
            </div>
            <div className="flex-[4] min-h-0 flex w-[115%] -ml-[15%] gap-3">
              <div className="flex-1 min-h-0 rounded-tl-[40px] rounded-bl-[40px] overflow-hidden relative">
                <AmbientVideo
                  src="/354006_medium.mp4"
                  poster="/354006_medium-poster.jpg"
                  aspectRatio="aspect-[4/3]"
                  rounded="rounded-tl-[40px] rounded-bl-[40px]"
                  overlayClassName="bg-charcoal/15"
                  playIconSize="w-14 h-14"
                  className="absolute inset-0 w-full h-full"
                />
              </div>
              <div className="flex-1 min-h-0 overflow-hidden relative">
                <AmbientVideo
                  src="/14949894_2160_3840_30fps.mp4"
                  poster="/14949894_2160_3840_30fps-poster.jpg"
                  aspectRatio="aspect-[4/3]"
                  rounded=""
                  overlayClassName="bg-charcoal/15"
                  playIconSize="w-14 h-14"
                  className="absolute inset-0 w-full h-full"
                />
              </div>
            </div>
          </div>
        </div>

        {/* Mobile hero */}
        <div className="flex flex-col md:hidden flex-1 min-h-0">
          <MobileHeroVariantA />
          <div className="shrink-0 px-6 pt-6 pb-6 w-[98%] max-w-[2000px] mx-auto">
            <h1 className="text-display font-light text-charcoal leading-[0.95] tracking-[-0.8px] max-w-[400px]">
              {t("hero.headline")}
            </h1>
            <p className="text-subheading font-light text-charcoal leading-[1.22] tracking-[-0.18px] max-w-[380px] mt-2">
              {t("hero.subhead")}
            </p>
            <div className="flex items-center gap-3 mt-4">
              <PillLinkButton href="/house" label={t("sections.viewAllHouses")} />
              <PillLinkButton href="/shop" label={t("sections.viewAllPlants")} />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}