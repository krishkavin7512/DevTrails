import { aqiCategory } from '@/lib/utils';

const LEVELS = [
  { max: 50,  label: 'Good',        color: '#22C55E' },
  { max: 100, label: 'Satisfactory', color: '#84CC16' },
  { max: 200, label: 'Moderate',    color: '#F59E0B' },
  { max: 300, label: 'Poor',        color: '#F97316' },
  { max: 400, label: 'Very Poor',   color: '#EF4444' },
  { max: 600, label: 'Severe',      color: '#991B1B' },
];

export default function AQIIndicator({ aqi }: { aqi: number }) {
  const cat = aqiCategory(aqi);
  const pct = Math.min((aqi / 500) * 100, 100);

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between text-sm">
        <span className="font-semibold text-white">{aqi} AQI</span>
        <span className="font-medium" style={{ color: cat.color }}>{cat.label}</span>
      </div>
      <div className="h-2 bg-white/[0.06] rounded-full overflow-hidden">
        <div
          className="h-full rounded-full transition-all duration-700"
          style={{ width: `${pct}%`, background: `linear-gradient(90deg, #22C55E, #F59E0B, #EF4444, #991B1B)` }}
        />
      </div>
      <div className="flex justify-between text-[10px] text-gray-600">
        <span>0</span>
        <span>200</span>
        <span>400</span>
        <span>500+</span>
      </div>
    </div>
  );
}
