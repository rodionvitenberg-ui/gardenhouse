interface HeroHeadlineProps {
  title: string;
  subtitle: string;
}

export default function HeroHeadline({ title, subtitle }: HeroHeadlineProps) {
  return (
    <div className="max-w-[600px]">
      <h1 className="text-display font-light text-charcoal leading-[0.95] tracking-[-0.02em] mb-4">
        {title}
      </h1>
      <p className="text-subheading font-light text-charcoal leading-[1.22] max-w-[480px]">
        {subtitle}
      </p>
    </div>
  );
}