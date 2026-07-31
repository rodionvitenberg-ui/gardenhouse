"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { useTranslations } from "next-intl";
import Image from "next/image";
import CTAButton from "@/components/CTAButton";
import InnerNav from "@/components/InnerNav";
import { fetchHouses, createBooking } from "@/lib/api";
import type { House, BookingRequestPayload } from "@/types";

export default function HouseDetailClient() {
  const th = useTranslations("house");
  const tc = useTranslations("contact");
  const { slug } = useParams<{ slug: string }>();
  const [house, setHouse] = useState<House | null>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState("");

  const [form, setForm] = useState({
    guest_name: "",
    guest_phone: "",
    guest_email: "",
    check_in: "",
    check_out: "",
    comment: "",
  });

  useEffect(() => {
    fetchHouses()
      .then((houses) => {
        const found = houses.find((h) => h.slug === slug);
        setHouse(found ?? null);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, [slug]);

  function handleChange(
    e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>
  ) {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!house) return;
    setSubmitting(true);
    setError("");

    try {
      const payload: BookingRequestPayload = {
        house: house.id,
        guest_name: form.guest_name,
        guest_phone: form.guest_phone,
        guest_email: form.guest_email || undefined,
        check_in: form.check_in,
        check_out: form.check_out,
        comment: form.comment || undefined,
      };
      await createBooking(payload);
      setSuccess(true);
    } catch {
      setError(th("errorGeneric"));
    } finally {
      setSubmitting(false);
    }
  }

  if (loading) {
    return (
      <>
        <InnerNav />
        <div className="w-[98%] max-w-[2000px] mx-auto px-6 pt-4 md:pt-8 pb-24">
          <div className="aspect-[16/9] rounded-[20px] bg-charcoal/5 animate-pulse mb-8" />
          <div className="h-8 w-64 bg-charcoal/5 animate-pulse rounded mb-4" />
          <div className="h-4 w-96 bg-charcoal/5 animate-pulse rounded" />
        </div>
      </>
    );
  }

  if (!house) {
    return (
      <>
        <InnerNav />
        <div className="w-[98%] max-w-[2000px] mx-auto px-6 pt-4 md:pt-8 pb-24">
          <h1 className="text-display font-light text-charcoal">
            {th("title")} {th("notFound")}
          </h1>
          <p className="text-body mt-4">{th("notFound")}</p>
        </div>
      </>
    );
  }

  if (success) {
    return (
      <>
        <InnerNav />
        <div className="w-[98%] max-w-[2000px] mx-auto px-6 pt-4 md:pt-8 pb-24 text-center">
          <h1 className="text-heading-lg font-light text-pine mb-4">
            {th("thankYou")}
          </h1>
          <p className="text-subheading font-light text-charcoal max-w-[480px] mx-auto">
            {th("bookingReceived")}
          </p>
        </div>
      </>
    );
  }

  return (
    <>
      <InnerNav />
      <div className="w-[98%] max-w-[2000px] mx-auto px-6 pt-4 md:pt-8 pb-24">
        <div className="grid grid-cols-2 gap-4 mb-12">
          {house.images.length > 0 ? (
            house.images.slice(0, 2).map((img) => (
              <div
                key={img.id}
                className="relative aspect-[3/2] rounded-[20px] overflow-hidden"
              >
                <Image
                  src={img.image}
                  alt={house.title}
                  fill
                  className="object-cover"
                  sizes="50vw"
                />
              </div>
            ))
          ) : (
            <div className="col-span-2 aspect-[3/1] rounded-[20px] bg-charcoal/5" />
          )}
        </div>

        <div className="max-w-[720px]">
          <h1 className="text-display font-light text-charcoal leading-[0.95] tracking-[-0.02em] mb-4">
            {house.title}
          </h1>
          <p className="text-heading-sm font-light text-charcoal mb-2">
            ${house.price_per_night} / night &middot;{" "}
            {th("maxGuests", { count: house.max_guests })}
          </p>
          <p className="text-body font-light text-charcoal leading-[1.29] mb-12">
            {house.description}
          </p>
        </div>

        <div className="max-w-[560px]">
          <h2 className="text-heading-sm font-light text-charcoal mb-6">
            {th("bookNow")}
          </h2>

          {error && <p className="text-body-sm text-ember mb-4">{error}</p>}

          <form onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label className="text-caption font-regular text-charcoal uppercase block mb-1">
                {tc("name")}
              </label>
              <input
                type="text"
                name="guest_name"
                value={form.guest_name}
                onChange={handleChange}
                required
                className="w-full text-body font-light text-charcoal border-b border-charcoal/30 bg-transparent outline-none py-1 focus:border-charcoal transition-colors"
              />
            </div>

            <div>
              <label className="text-caption font-regular text-charcoal uppercase block mb-1">
                {tc("phone")}
              </label>
              <input
                type="tel"
                name="guest_phone"
                value={form.guest_phone}
                onChange={handleChange}
                required
                className="w-full text-body font-light text-charcoal border-b border-charcoal/30 bg-transparent outline-none py-1 focus:border-charcoal transition-colors"
              />
            </div>

            <div>
              <label className="text-caption font-regular text-charcoal uppercase block mb-1">
                {tc("email")}
              </label>
              <input
                type="email"
                name="guest_email"
                value={form.guest_email}
                onChange={handleChange}
                className="w-full text-body font-light text-charcoal border-b border-charcoal/30 bg-transparent outline-none py-1 focus:border-charcoal transition-colors"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-caption font-regular text-charcoal uppercase block mb-1">
                  {th("checkIn")}
                </label>
                <input
                  type="date"
                  name="check_in"
                  value={form.check_in}
                  onChange={handleChange}
                  required
                  className="w-full text-body font-light text-charcoal border-b border-charcoal/30 bg-transparent outline-none py-1 focus:border-charcoal transition-colors"
                />
              </div>
              <div>
                <label className="text-caption font-regular text-charcoal uppercase block mb-1">
                  {th("checkOut")}
                </label>
                <input
                  type="date"
                  name="check_out"
                  value={form.check_out}
                  onChange={handleChange}
                  required
                  className="w-full text-body font-light text-charcoal border-b border-charcoal/30 bg-transparent outline-none py-1 focus:border-charcoal transition-colors"
                />
              </div>
            </div>

            <div>
              <label className="text-caption font-regular text-charcoal uppercase block mb-1">
                {tc("message")}
              </label>
              <textarea
                name="comment"
                value={form.comment}
                onChange={handleChange}
                rows={3}
                className="w-full text-body font-light text-charcoal border-b border-charcoal/30 bg-transparent outline-none py-1 focus:border-charcoal transition-colors resize-none"
              />
            </div>

            <div className="pt-2">
              <CTAButton
                type="submit"
                label={submitting ? (th("sending") as string) : (th("bookNow") as string)}
                className="w-full"
              />
            </div>
          </form>
        </div>
      </div>
    </>
  );
}