'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import Image from 'next/image';
import MobileMenuVariantB from '@/components/MobileMenuVariantB';
import LocaleSwitcher from '@/components/LocaleSwitcher';
import { getNavLinks } from '@/i18n/navigation-links';

export default function InnerNav() {
  const [menuOpen, setMenuOpen] = useState(false);
  const t = useTranslations('nav');
  const navLinks = getNavLinks(t);

  return (
    <>
      <nav className="flex items-center justify-between px-6 md:px-6 py-6 md:py-8 w-[98%] max-w-[2000px] mx-auto">
        {/* Logo — logo.png desktop, logo1.png mobile */}
        <Link href="/" className="no-underline shrink-0 md:-ml-2">
          <Image
            src="/logo.png"
            alt="Father's Garden"
            width={800}
            height={180}
            className="hidden md:block h-28 w-auto"
            priority
          />
          <Image
            src="/logo1.png"
            alt="Father's Garden"
            width={320}
            height={72}
            className="block md:hidden h-22 w-auto"
            priority
          />
        </Link>

        {/* Desktop nav links — large, uppercase, Helvetica Condensed */}
        <div className="hidden md:flex items-center gap-10">
          {navLinks.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className="text-nav font-helvetica-condensed font-black text-charcoal/80 no-underline hover:text-pine transition-colors uppercase tracking-[0.04em]"
            >
              {link.label}
            </Link>
          ))}
          <div className="ml-2">
            <LocaleSwitcher />
          </div>
        </div>

        {/* Mobile: language toggle + burger button */}
        <div className="flex md:hidden items-center gap-1.5">
          <LocaleSwitcher variant="mobilePill" />

          {/* Burger button */}
          <button
            onClick={() => setMenuOpen(!menuOpen)}
            className="flex flex-col gap-[6px] p-3 -mr-2 rounded-[12px] hover:bg-charcoal/5 active:bg-charcoal/10 transition-colors"
            aria-label="Toggle menu"
          >
            <span className={`block w-7 h-[2px] bg-charcoal rounded-sm transition-all duration-300 ease-[cubic-bezier(0.32,0.72,0,1)] origin-center ${menuOpen ? 'rotate-45 translate-y-[8px]' : ''}`} />
            <span className={`block w-7 h-[2px] bg-charcoal rounded-sm transition-all duration-300 ease-[cubic-bezier(0.32,0.72,0,1)] ${menuOpen ? 'opacity-0 scale-x-0' : ''}`} />
            <span className={`block w-7 h-[2px] bg-charcoal rounded-sm transition-all duration-300 ease-[cubic-bezier(0.32,0.72,0,1)] origin-center ${menuOpen ? '-rotate-45 -translate-y-[8px]' : ''}`} />
          </button>
        </div>
      </nav>

      {/* Mobile menu — full-screen overlay */}
      <MobileMenuVariantB
        open={menuOpen}
        onClose={() => setMenuOpen(false)}
        navLinks={navLinks}
      />
    </>
  );
}
