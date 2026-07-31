interface CTAButtonProps {
  label: string;
  onClick?: () => void;
  type?: 'button' | 'submit';
  className?: string;
}

export default function CTAButton({ label, onClick, type = 'button', className = '' }: CTAButtonProps) {
  return (
    <button
      type={type}
      onClick={onClick}
      className={`rounded-[20px] bg-charcoal px-6 py-3 text-body font-regular text-snow hover:opacity-90 transition-opacity cursor-pointer ${className}`}
    >
      {label}
    </button>
  );
}
