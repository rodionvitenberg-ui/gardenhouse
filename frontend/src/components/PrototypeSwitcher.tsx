'use client';

import { useRouter, useSearchParams } from 'next/navigation';
import { useCallback, useEffect } from 'react';

interface Props {
  variants: string[];
  labels: Record<string, string>;
}

export default function PrototypeSwitcher({ variants, labels }: Props) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const current = searchParams.get('variant') ?? variants[0];

  const goTo = useCallback(
    (key: string) => {
      const params = new URLSearchParams(searchParams.toString());
      params.set('variant', key);
      router.replace(`?${params.toString()}`, { scroll: false });
    },
    [router, searchParams],
  );

  const cycle = useCallback(
    (dir: -1 | 1) => {
      const idx = variants.indexOf(current);
      const next = (idx + dir + variants.length) % variants.length;
      goTo(variants[next]);
    },
    [current, variants, goTo],
  );

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement).tagName;
      if (tag === 'INPUT' || tag === 'TEXTAREA' || (e.target as HTMLElement).isContentEditable) return;
      if (e.key === 'ArrowLeft') { e.preventDefault(); cycle(-1); }
      if (e.key === 'ArrowRight') { e.preventDefault(); cycle(1); }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [cycle]);

  if (process.env.NODE_ENV === 'production') return null;

  return (
    <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 flex items-center gap-4 bg-charcoal/90 backdrop-blur-md text-snow rounded-[99px] px-5 py-2.5 shadow-lg select-none">
      <button
        onClick={() => cycle(-1)}
        className="text-snow/70 hover:text-snow transition-colors text-lg leading-none px-1"
        aria-label="Previous variant"
      >
        ‹
      </button>

      <span className="text-body-sm font-regular whitespace-nowrap tracking-[-0.07px]">
        {current} — {labels[current] ?? current}
      </span>

      <button
        onClick={() => cycle(1)}
        className="text-snow/70 hover:text-snow transition-colors text-lg leading-none px-1"
        aria-label="Next variant"
      >
        ›
      </button>
    </div>
  );
}