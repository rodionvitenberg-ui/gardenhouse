import Image from 'next/image';

interface JournalArticleCardProps {
  src: string;
  alt: string;
  headline: string;
}

export default function JournalArticleCard({ src, alt, headline }: JournalArticleCardProps) {
  return (
    <div className="relative aspect-[4/5] overflow-hidden rounded-[20px]">
      <Image
        src={src}
        alt={alt}
        fill
        className="object-cover"
        sizes="(max-width: 768px) 100vw, 33vw"
      />
      {/* Snow overlay panel at bottom-left */}
      <div className="absolute bottom-0 left-0 m-5 rounded-[12px] bg-snow p-5 max-w-[260px]">
        <p className="text-caption font-regular text-charcoal uppercase mb-1">
          HOUSES
        </p>
        <h3 className="text-heading-sm font-light text-charcoal leading-[1.15] tracking-[-0.02em] line-clamp-2">
          {headline}
        </h3>
      </div>
    </div>
  );
}