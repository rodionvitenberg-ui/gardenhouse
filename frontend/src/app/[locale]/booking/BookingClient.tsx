"use client";

import { useEffect, useState, useMemo } from "react";
import { useTranslations } from "next-intl";
import DatePicker from "react-datepicker";
import "react-datepicker/dist/react-datepicker.css";
import InnerNav from "@/components/InnerNav";
import CTAButton from "@/components/CTAButton";
import { fetchHouses, createBooking } from "@/lib/api";
import type { House, BookingRequestPayload } from "@/types";

const PRICE_PER_NIGHT = 120;
const MIN_NIGHTS = 2;
const WHATSAPP_URL = "https://wa.me/996555953468";
const TELEGRAM_URL = "https://t.me/996555953468";

function toDateStr(d: Date | null): string {
  if (!d) return "";
  return d.toISOString().split("T")[0];
}
function calcNights(a: Date | null, b: Date | null): number {
  if (!a || !b) return 0;
  return Math.max(0, (b.getTime() - a.getTime()) / (1000 * 60 * 60 * 24));
}

export default function BookingClient() {
  const t = useTranslations("booking");
  const [houses, setHouses] = useState<House[]>([]);
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState("");

  const [form, setForm] = useState({
    guest_name: "", guest_email: "", guest_phone: "",
    check_in: null as Date | null, check_out: null as Date | null, comment: "",
  });

  useEffect(() => { fetchHouses().then(setHouses).catch(() => {}); }, []);

  const nights = useMemo(() => calcNights(form.check_in, form.check_out), [form.check_in, form.check_out]);
  const checkInStr = useMemo(() => toDateStr(form.check_in), [form.check_in]);
  const checkOutStr = useMemo(() => toDateStr(form.check_out), [form.check_out]);
  const total = nights * PRICE_PER_NIGHT;
  const validNights = nights >= MIN_NIGHTS;

  function handleChange(e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) {
    setForm((p) => ({ ...p, [e.target.name]: e.target.value }));
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!houses.length || !validNights) return;
    setSubmitting(true); setError("");
    try {
      await createBooking({
        house: houses[0].id, guest_name: form.guest_name, guest_phone: form.guest_phone,
        guest_email: form.guest_email || undefined, check_in: checkInStr, check_out: checkOutStr,
        comment: form.comment || undefined,
      });
      setSuccess(true);
    } catch { setError(t("errorGeneric")); } finally { setSubmitting(false); }
  }

  if (success) {
    return (
      <>
        <InnerNav />
        <div className="w-[98%] max-w-[2000px] mx-auto px-6 pt-24 pb-24 text-center">
          <h1 className="text-heading-lg font-light text-pine mb-4">{t("thankYou")}</h1>
          <p className="text-subheading font-light text-charcoal max-w-[480px] mx-auto">{t("bookingReceived")}</p>
        </div>
      </>
    );
  }

  return (
    <>
      <InnerNav />
      <div className="w-[98%] max-w-[2000px] mx-auto px-6 pt-6 md:pt-12 pb-24">
        {/* Symmetric header — centered */}
        <div className="text-center mb-12 md:mb-16">
          <div className="inline-block px-5 py-2 rounded-[99px] border border-charcoal/20 text-caption font-regular text-charcoal/60 uppercase tracking-[0.06em] mb-5">
            {t("priceNote")}
          </div>
          <h1 className="text-heading-lg md:text-display font-light text-charcoal leading-[0.95] tracking-[-0.03em] max-w-[600px] mx-auto">
            {t("title")}
          </h1>
          <p className="text-subheading font-light text-charcoal/60 leading-[1.22] max-w-[400px] mx-auto mt-4">
            {t("subtitle")}
          </p>
        </div>

        {error && <p className="text-body-sm text-ember text-center mb-6">{error}</p>}

        {/* Centered form — max-w-[560px] mx-auto */}
        <form onSubmit={handleSubmit} className="max-w-[560px] mx-auto space-y-6">
          {/* Dates — side by side */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="text-caption font-regular text-charcoal uppercase block mb-1">{t("checkIn")}</label>
              <DatePicker selected={form.check_in}
                onChange={(d: Date | null) => setForm((p) => ({ ...p, check_in: d }))}
                selectsStart startDate={form.check_in} endDate={form.check_out} minDate={new Date()}
                placeholderText="Select" dateFormat="MMM d, yyyy"
                className="w-full text-body font-light text-charcoal border-b border-charcoal/30 bg-transparent outline-none py-1" wrapperClassName="w-full" />
            </div>
            <div>
              <label className="text-caption font-regular text-charcoal uppercase block mb-1">{t("checkOut")}</label>
              <DatePicker selected={form.check_out}
                onChange={(d: Date | null) => setForm((p) => ({ ...p, check_out: d }))}
                selectsEnd startDate={form.check_in} endDate={form.check_out} minDate={form.check_in || new Date()}
                placeholderText="Select" dateFormat="MMM d, yyyy"
                className="w-full text-body font-light text-charcoal border-b border-charcoal/30 bg-transparent outline-none py-1" wrapperClassName="w-full" />
            </div>
          </div>

          {/* Price preview on same row */}
          {nights > 0 && (
            <div className="flex items-center justify-center gap-3 text-body font-regular text-pine">
              <span>{t("total")}: ${total}</span>
              {!validNights && <span className="text-ember text-body-sm">({t("minNights")})</span>}
              {validNights && <span className="text-charcoal/40 text-body-sm">({nights} {t("nights")})</span>}
            </div>
          )}

          {/* Name + Email — side by side */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="text-caption font-regular text-charcoal uppercase block mb-1">{t("yourName")}</label>
              <input type="text" name="guest_name" value={form.guest_name} onChange={handleChange} required
                className="w-full text-body font-light text-charcoal border-b border-charcoal/30 bg-transparent outline-none py-1" />
            </div>
            <div>
              <label className="text-caption font-regular text-charcoal uppercase block mb-1">{t("yourEmail")}</label>
              <input type="email" name="guest_email" value={form.guest_email} onChange={handleChange} required
                className="w-full text-body font-light text-charcoal border-b border-charcoal/30 bg-transparent outline-none py-1" />
            </div>
          </div>

          {/* Phone — full width */}
          <div>
            <label className="text-caption font-regular text-charcoal uppercase block mb-1">{t("yourPhone")}</label>
            <input type="tel" name="guest_phone" value={form.guest_phone} onChange={handleChange} required
              className="w-full text-body font-light text-charcoal border-b border-charcoal/30 bg-transparent outline-none py-1" />
          </div>

          <div>
            <label className="text-caption font-regular text-charcoal uppercase block mb-1">{t("comment")}</label>
            <textarea name="comment" value={form.comment} onChange={handleChange} rows={2}
              className="w-full text-body font-light text-charcoal border-b border-charcoal/30 bg-transparent outline-none py-1 resize-none" />
          </div>

          <div className="pt-2">
            <CTAButton type="submit" label={submitting ? (t("sending") as string) : (t("send") as string)} className="w-full" />
          </div>

          {/* Social buttons — centered, symmetrical */}
          <div className="pt-6 text-center">
            <p className="text-caption font-regular text-charcoal/50 uppercase mb-4">{t("orDirect")}</p>
            <div className="flex justify-center gap-4">
              <a href={WHATSAPP_URL} target="_blank" rel="noopener noreferrer"
                className="inline-flex items-center gap-2 rounded-[99px] border border-charcoal/30 px-5 py-2.5 text-body-sm font-regular text-charcoal no-underline hover:text-pine hover:border-pine transition-colors">{t("whatsapp")} →</a>
              <a href={TELEGRAM_URL} target="_blank" rel="noopener noreferrer"
                className="inline-flex items-center gap-2 rounded-[99px] border border-charcoal/30 px-5 py-2.5 text-body-sm font-regular text-charcoal no-underline hover:text-pine hover:border-pine transition-colors">{t("telegram")} →</a>
            </div>
          </div>
        </form>
      </div>
    </>
  );
}