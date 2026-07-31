'use client';

import AmbientVideo from '@/components/AmbientVideo';

const HERO_VIDEO = {
  src: '/14949894_2160_3840_30fps.mp4',
  poster: '/14949894_2160_3840_30fps-poster.jpg',
};

export default function MobileHeroVariantA() {
  return (
    <div className="relative w-full h-[45dvh] shrink-0 overflow-hidden">
      <AmbientVideo
        src={HERO_VIDEO.src}
        poster={HERO_VIDEO.poster}
        aspectRatio=""
        rounded=""
        overlayClassName="bg-charcoal/15"
        playIconSize="w-12 h-12"
        className="w-full h-full"
      />
    </div>
  );
}
