'use client';

import DateInputPair from './DateInputPair';
import CTAButton from './CTAButton';

export default function MarigoldSearchBar() {
  return (
    <div className="mx-auto flex w-full max-w-[960px] items-center gap-0 rounded-[40px] bg-marigold px-6 py-4">
      {/* Region / Category */}
      <div className="flex-1 min-w-0">
        <p className="text-caption font-regular text-charcoal uppercase">Category</p>
        <div className="flex items-center justify-between">
          <span className="text-body font-light text-charcoal underline underline-offset-2">
            All Categories
          </span>
          <span className="text-body-sm text-charcoal">▾</span>
        </div>
      </div>

      {/* Hairline divider */}
      <div className="h-8 w-px bg-charcoal/30 mx-4" />

      {/* Date input pair */}
      <div className="flex-1 min-w-0">
        <DateInputPair />
      </div>

      {/* Hairline divider */}
      <div className="h-8 w-px bg-charcoal/30 mx-4" />

      {/* Guests */}
      <div className="flex-1 min-w-0">
        <p className="text-caption font-regular text-charcoal uppercase">Guests</p>
        <div className="flex items-center justify-between">
          <span className="text-body font-light text-charcoal underline underline-offset-2">
            2 Guests
          </span>
          <span className="text-body-sm text-charcoal">▾</span>
        </div>
      </div>

      {/* Search button */}
      <div className="ml-4 shrink-0">
        <CTAButton label="Search" />
      </div>
    </div>
  );
}