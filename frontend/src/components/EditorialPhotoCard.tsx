import Image from 'next/image';

interface EditorialPhotoCardProps {
  src: string;
  alt: string;
  label: string;
  description: string;
}

export default function EditorialPhotoCard({ src, alt, label, description }: EditorialPhotoCardProps) {
  return (
    <div>
      <div className="relative aspect-[4/3] overflow-hidden rounded-[20px] bg-paper">
        <Image
          src={src}
          alt={alt}
          fill
          className="object-cover"
          sizes="(max-width: 768px) 100vw, 33vw"
        />
      </div>
      <div className="mt-4">
        <p className="text-caption font-regular text-charcoal uppercase tracking-[-0.06px]">
          {label}
        </p>
        <p className="text-subheading font-light text-charcoal leading-[1.22] mt-1">
          {description}
        </p>
      </div>
    </div>
  );
}