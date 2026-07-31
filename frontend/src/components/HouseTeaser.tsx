'use client';

import { useTranslations } from 'next-intl';
import CTAButton from '@/components/CTAButton';
import PillLinkButton from '@/components/PillLinkButton';
import AmbientVideo from '@/components/AmbientVideo';
import type { House } from '@/types';

interface HouseTeaserProps {
  houses: House[];
}

export default function HouseTeaser({ houses }: HouseTeaserProps) {
  const t = useTranslations('sections');
  const house = houses[0];

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-10 md:gap-16 items-center">
      {/* Видео-блок (первый кадр — постер, запуск по клику) */}
      <div className="relative aspect-[4/3] overflow-hidden rounded-[20px] bg-paper">
        <AmbientVideo
          src="/14838732_2160_3840_24fps.mp4"
          poster="/14838732_2160_3840_24fps-poster.jpg"
          aspectRatio="aspect-[4/3]"
          rounded="rounded-[20px]"
          overlayClassName="bg-charcoal/10"
          playIconSize="w-14 h-14"
        />
      </div>

      {/* Текст + кнопки */}
      <div>
        <h3 className="text-heading font-light text-charcoal leading-[1.07] tracking-[-0.42px] mb-4">
          {house?.title ?? t('stayFallbackTitle')}
        </h3>
        <p className="text-body font-light text-charcoal leading-[1.29] mb-8 max-w-[65ch]">
          {house?.description ??
            t('stayFallbackDesc')}
        </p>

        {/* Характеристики */}
        {house && (
          <div className="flex gap-8 mb-8">
            {house.max_guests > 0 && (
              <div>
                <p className="text-caption font-regular text-charcoal/40 uppercase tracking-[-0.06px] mb-1">
                  {t('guests')}
                </p>
                <p className="text-body font-regular text-charcoal tabular-nums">
                  {house.max_guests}
                </p>
              </div>
            )}
            {house.price_per_night && (
              <div>
                <p className="text-caption font-regular text-charcoal/40 uppercase tracking-[-0.06px] mb-1">
                  {t('from')}
                </p>
                <p className="text-body font-regular text-charcoal tabular-nums">
                  ${house.price_per_night}{t('perNight')}
                </p>
              </div>
            )}
          </div>
        )}

        {/* Две кнопки */}
        <div className="flex flex-wrap items-center gap-4">
          <PillLinkButton href="/house" label={t('viewAllHouses')} />
          <CTAButton
            label={t('bookYourStay')}
            onClick={() => {
              window.location.href = '/booking';
            }}
          />
        </div>
      </div>
    </div>
  );
}