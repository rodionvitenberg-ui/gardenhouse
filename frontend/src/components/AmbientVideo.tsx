'use client';

import { useState, useRef, forwardRef, useImperativeHandle } from 'react';
import { assetUrl } from '@/lib/asset';

export interface AmbientVideoHandle {
  play: () => void;
}

interface AmbientVideoProps {
  /** URL видео — загружается только при клике */
  src: string;
  /** URL статичного постера (первый кадр) */
  poster: string;
  /** Tailwind-класс для aspect-ratio: "aspect-[3/4]", "aspect-[4/3]", "aspect-[16/9]", "aspect-[21/9]" */
  aspectRatio?: string;
  /** Tailwind border-radius: "rounded-[20px]", "rounded-[40px]" */
  rounded?: string;
  /** Класс оверлея поверх постера/видео: "bg-charcoal/20", "bg-charcoal/40" */
  overlayClassName?: string;
  /** Размер иконки play: "w-12 h-12", "w-16 h-16" */
  playIconSize?: string;
  /** Дополнительные классы для контейнера */
  className?: string;
}

/**
 * AmbientVideo — видео, которое НЕ грузится до клика пользователя.
 * Изначально показывает статичный постер (первый кадр) с полупрозрачной иконкой play.
 * При клике — заменяет постер на <video> с autoplay muted loop playsinline.
 *
 * Это позволяет не грузить мегабайты видео без тапа, но при этом
 * страница выглядит живой за счёт лёгкого постера.
 *
 * Exposes: play() через ref — для программного запуска (например, при double-tap из карусели).
 */
const AmbientVideo = forwardRef<AmbientVideoHandle, AmbientVideoProps>(function AmbientVideo(
  {
    src,
    poster,
    aspectRatio = 'aspect-[4/3]',
    rounded = 'rounded-[20px]',
    overlayClassName = 'bg-charcoal/20',
    playIconSize = 'w-14 h-14',
    className = '',
  }: AmbientVideoProps,
  ref
) {
  const [playing, setPlaying] = useState(false);
  const videoRef = useRef<HTMLVideoElement>(null);

  const startPlayback = () => {
    if (playing) return;
    setPlaying(true);
    requestAnimationFrame(() => {
      videoRef.current?.play().catch(() => {
        // браузер может заблокировать автовоспроизведение — игнорируем
      });
    });
  };

  useImperativeHandle(ref, () => ({
    play: startPlayback,
  }));

  const handleClick = () => {
    startPlayback();
  };

  return (
    <div
      className={`relative overflow-hidden ${aspectRatio} ${rounded} ${className} cursor-pointer group`}
      onClick={handleClick}
      role="button"
      tabIndex={0}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          handleClick();
        }
      }}
      aria-label="Play video"
    >
      {/* Постер (виден до клика) */}
      {!playing && (
        <>
          <img
            src={assetUrl(poster)}
            alt=""
            className="absolute inset-0 w-full h-full object-cover"
            loading="lazy"
          />
          <div className={`absolute inset-0 ${overlayClassName}`} />

          {/* Иконка Play — полупрозрачная, по центру */}
          <div className="absolute inset-0 flex items-center justify-center z-10">
            <div
              className={`${playIconSize} rounded-full bg-snow/70 flex items-center justify-center transition-transform duration-300 group-hover:scale-110`}
            >
              <svg
                className="w-1/2 h-1/2 text-charcoal ml-0.5"
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <path d="M8 5.14v14l11-7-11-7z" />
              </svg>
            </div>
          </div>
        </>
      )}

      {/* Видео (появляется только после клика) */}
      {playing && (
        <video
          ref={videoRef}
          className={`absolute inset-0 w-full h-full object-cover ${overlayClassName ? '' : ''}`}
            src={assetUrl(src)}
            muted
            autoPlay
            loop
            playsInline
            preload="auto"
          />
      )}

      {/* Оверлей поверх видео после старта */}
      {playing && overlayClassName && (
        <div className={`absolute inset-0 pointer-events-none ${overlayClassName}`} />
      )}
    </div>
  );
});

export default AmbientVideo;