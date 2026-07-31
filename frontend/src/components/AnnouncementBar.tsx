'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';

export default function AnnouncementBar() {
  const t = useTranslations('announcement');
  const [isVisible, setIsVisible] = useState(true);

  if (!isVisible) return null;

  return (
    <div className="relative flex h-14 items-center justify-center bg-morning-sky px-4 md:px-8">
      <p className="text-body-sm font-regular tracking-[-0.01em] text-charcoal">
        🌿 {t('text')}{' '}
        <span className="font-regular text-ember underline decoration-ember underline-offset-2">
          {t('cta')}
        </span>
      </p>

      <button
        onClick={() => setIsVisible(false)}
        className="absolute right-4 md:right-6 top-1/2 -translate-y-1/2 flex items-center justify-center w-8 h-8 rounded-full text-charcoal hover:bg-charcoal/10 transition-colors"
        aria-label="Dismiss announcement"
      >
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M3 3L13 13M13 3L3 13" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
        </svg>
      </button>
    </div>
  );
}
