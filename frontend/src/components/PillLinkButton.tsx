import Link from 'next/link';

interface PillLinkButtonProps {
  href: string;
  label: string;
  showArrow?: boolean;
}

export default function PillLinkButton({ href, label, showArrow = true }: PillLinkButtonProps) {
  return (
    <Link
      href={href}
      className="inline-flex items-center gap-1 rounded-[99px] border border-charcoal px-[10px] py-[10px] text-body-sm font-regular text-charcoal no-underline hover:text-pine hover:border-pine transition-colors"
    >
      {label}
      {showArrow && <span>→</span>}
    </Link>
  );
}