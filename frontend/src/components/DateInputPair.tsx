interface DateInputPairProps {
  arrivalLabel?: string;
  departureLabel?: string;
  arrivalValue?: string;
  departureValue?: string;
}

export default function DateInputPair({
  arrivalLabel = 'Arrival',
  departureLabel = 'Departure',
  arrivalValue = '',
  departureValue = '',
}: DateInputPairProps) {
  return (
    <div className="flex items-center gap-1.5">
      <div>
        <p className="text-caption font-regular text-charcoal uppercase">{arrivalLabel}</p>
        <input
          type="date"
          defaultValue={arrivalValue}
          className="text-body font-light text-charcoal underline underline-offset-2 border-none bg-transparent outline-none w-full"
        />
      </div>
      <span className="text-body-sm text-charcoal mt-5">→</span>
      <div>
        <p className="text-caption font-regular text-charcoal uppercase">{departureLabel}</p>
        <input
          type="date"
          defaultValue={departureValue}
          className="text-body font-light text-charcoal underline underline-offset-2 border-none bg-transparent outline-none w-full"
        />
      </div>
    </div>
  );
}