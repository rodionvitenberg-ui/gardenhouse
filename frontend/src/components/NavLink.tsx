'use client';

import { useRef, useCallback } from 'react';
import Link from 'next/link';
import gsap from 'gsap';

interface NavLinkProps {
  href: string;
  label: string;
  className?: string;
}

export default function NavLink({ href, label, className = '' }: NavLinkProps) {
  const lineRef = useRef<HTMLSpanElement>(null);
  const tlRef = useRef<gsap.core.Timeline | null>(null);

  const handleMouseEnter = useCallback(() => {
    if (!lineRef.current) return;
    tlRef.current?.kill();
    tlRef.current = gsap.timeline().fromTo(
      lineRef.current,
      { scaleX: 0, y: 6 },
      { scaleX: 1, y: 0, duration: 0.4, ease: 'power3.out' },
    );
  }, []);

  const handleMouseLeave = useCallback(() => {
    if (!lineRef.current) return;
    tlRef.current?.kill();
    tlRef.current = gsap.timeline().to(lineRef.current, {
      scaleX: 0,
      y: 4,
      duration: 0.25,
      ease: 'power2.in',
    });
  }, []);

  return (
    <Link
      href={href}
      className={`relative inline-block no-underline ${className}`}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
    >
      {label}
      <span
        ref={lineRef}
        className="absolute bottom-[-4px] left-0 w-full h-[2.5px] bg-current origin-left scale-x-0"
      />
    </Link>
  );
}