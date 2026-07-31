"use client";

import { useEffect } from "react";
import Image from "next/image";
import { Link } from "@/i18n/navigation";
import LocaleSwitcher from "@/components/LocaleSwitcher";

interface Props {
  open: boolean;
  onClose: () => void;
  navLinks: { label: string; href: string }[];
}

export default function MobileMenuVariantB({ open, onClose, navLinks }: Props) {
  // Lock body scroll when open
  useEffect(() => {
    if (open) {
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = "";
    }
    return () => {
      document.body.style.overflow = "";
    };
  }, [open]);

  return (
    <div
      className={`fixed inset-0 z-50 bg-paper flex flex-col transition-all duration-400 ease-[cubic-bezier(0.32,0.72,0,1)] ${
        open
          ? "opacity-100 pointer-events-auto"
          : "opacity-0 pointer-events-none"
      }`}
      aria-hidden={!open}
    >
      {/* ── Top bar — зеркалит навбар: логотип слева, крестик на месте бургера ── */}
      <div className="px-6 py-6 w-[98%] max-w-[2000px] mx-auto">
        <div className="flex items-center justify-between">
          {/* Логотип — точно как в навбаре (mobile logo) */}
          <Link
            href="/"
            onClick={onClose}
            className="no-underline shrink-0"
          >
            <Image
              src="/logo1.png"
              alt="Father's Garden"
              width={320}
              height={72}
              className="h-22 w-auto"
              priority
            />
          </Link>

          {/* Крестик — на месте бургера, те же размеры и padding */}
          <button
            onClick={onClose}
            className="flex items-center justify-center p-3 -mr-2 rounded-[12px] text-charcoal hover:bg-charcoal/5 active:bg-charcoal/10 transition-colors"
            aria-label="Close menu"
          >
            <svg
              width="28"
              height="28"
              viewBox="0 0 28 28"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
            >
              <path d="M6 6L22 22M22 6L6 22" />
            </svg>
          </button>
        </div>
      </div>

      {/* ── Nav links — крупнее, центрированы по вертикали ── */}
      <nav className="flex-1 flex flex-col items-center justify-center gap-14 pb-16">
        {navLinks.map((link) => (
          <Link
            key={link.href}
            href={link.href}
            onClick={onClose}
            className="text-heading font-light text-charcoal tracking-[-0.02em] no-underline hover:text-pine transition-colors"
            style={{
              fontFamily: "var(--font-neue-haas-unica)",
              fontWeight: 300,
            }}
          >
            {link.label}
          </Link>
        ))}
      </nav>

      {/* ── Bottom: language toggle ── */}
      <div className="flex justify-center pb-10">
        <LocaleSwitcher variant="mobilePill" />
      </div>
    </div>
  );
}
