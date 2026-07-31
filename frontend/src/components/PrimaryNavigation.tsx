'use client';

import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import NavLink from '@/components/NavLink';
import LocaleSwitcher from '@/components/LocaleSwitcher';
import { getNavLinks } from '@/i18n/navigation-links';

export default function PrimaryNavigation() {
  const t = useTranslations('nav');
  const navLinks = getNavLinks(t);

  return (
    <nav className="flex items-center justify-between px-6 py-4 w-[98%] max-w-[2000px] mx-auto">
      {/* Brand wordmark */}
      <Link href="/" className="text-display text-pine font-light leading-[0.95] tracking-[-0.02em] no-underline">
        FATHER'S GARDEN
      </Link>

      {/* Nav links + Language toggle */}
      <div className="flex items-center gap-5">
        {navLinks.map((link) => (
          <NavLink
            key={link.href}
            href={link.href}
            label={link.label}
            className="text-body font-black text-charcoal"
          />
        ))}

        <LocaleSwitcher />
      </div>
    </nav>
  );
}
