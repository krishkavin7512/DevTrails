/** Format paise → rupees display string */
export function fmt(paise: number): string {
  const r = paise / 100;
  if (r >= 10_00_000) return `₹${(r / 10_00_000).toFixed(1)}Cr`;
  if (r >= 1_00_000)  return `₹${(r / 1_00_000).toFixed(1)}L`;
  if (r >= 1_000)     return `₹${(r / 1_000).toFixed(1)}K`;
  return `₹${r.toFixed(0)}`;
}

/** Format raw rupees (not paise) */
export function fmtRupees(amount: number): string {
  if (amount >= 10_00_000) return `₹${(amount / 10_00_000).toFixed(1)}Cr`;
  if (amount >= 1_00_000)  return `₹${(amount / 1_00_000).toFixed(1)}L`;
  if (amount >= 1_000)     return `₹${(amount / 1_000).toFixed(1)}K`;
  return `₹${amount.toFixed(0)}`;
}

export function formatDate(date: string | Date): string {
  return new Date(date).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
}

export function timeAgo(date: string | Date): string {
  const diff = Date.now() - new Date(date).getTime();
  const m = Math.floor(diff / 60000);
  const h = Math.floor(diff / 3600000);
  const d = Math.floor(diff / 86400000);
  if (m < 1) return 'just now';
  if (m < 60) return `${m}m ago`;
  if (h < 24) return `${h}h ago`;
  if (d < 30) return `${d}d ago`;
  return formatDate(date);
}

export function getGreeting(): string {
  const h = new Date().getHours();
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

export function aqiCategory(aqi: number): { label: string; color: string; bg: string } {
  if (aqi <= 50)  return { label: 'Good',      color: '#22C55E', bg: '#052e16' };
  if (aqi <= 100) return { label: 'Satisfactory', color: '#84CC16', bg: '#1a2e05' };
  if (aqi <= 200) return { label: 'Moderate',  color: '#F59E0B', bg: '#431407' };
  if (aqi <= 300) return { label: 'Poor',       color: '#F97316', bg: '#431407' };
  if (aqi <= 400) return { label: 'Very Poor',  color: '#EF4444', bg: '#450a0a' };
  return           { label: 'Severe',            color: '#991B1B', bg: '#3d0000' };
}

export function riskTierColors(tier: string): { text: string; bg: string; border: string } {
  switch (tier) {
    case 'Low':      return { text: '#22C55E', bg: 'rgba(34,197,94,0.12)',  border: 'rgba(34,197,94,0.3)' };
    case 'Medium':   return { text: '#F59E0B', bg: 'rgba(245,158,11,0.12)', border: 'rgba(245,158,11,0.3)' };
    case 'High':     return { text: '#F97316', bg: 'rgba(249,115,22,0.12)', border: 'rgba(249,115,22,0.3)' };
    case 'VeryHigh': return { text: '#EF4444', bg: 'rgba(239,68,68,0.12)',  border: 'rgba(239,68,68,0.3)' };
    default:         return { text: '#6B7280', bg: 'rgba(107,114,128,0.12)', border: 'rgba(107,114,128,0.3)' };
  }
}

export const TRIGGER_META: Record<string, { emoji: string; label: string; color: string; bg: string; desc: string }> = {
  HeavyRain:        { emoji: '🌧️', label: 'Heavy Rainfall',   color: '#60A5FA', bg: 'rgba(96,165,250,0.1)',   desc: '>64mm/hr sustained rain' },
  ExtremeHeat:      { emoji: '🌡️', label: 'Extreme Heat',     color: '#FB923C', bg: 'rgba(251,146,60,0.1)',   desc: 'Feels-like >48°C' },
  SevereAQI:        { emoji: '😷', label: 'Severe AQI',       color: '#C084FC', bg: 'rgba(192,132,252,0.1)',  desc: 'Air Quality Index >400' },
  Flooding:         { emoji: '🌊', label: 'Flooding',         color: '#22D3EE', bg: 'rgba(34,211,238,0.1)',   desc: 'Sustained rain 6+ hrs' },
  SocialDisruption: { emoji: '🚫', label: 'Social Disruption', color: '#FBBF24', bg: 'rgba(251,191,36,0.1)', desc: 'Curfew / Strike / Shutdown' },
};

export const STATUS_META: Record<string, { label: string; color: string; bg: string }> = {
  AutoInitiated: { label: 'Auto Initiated', color: '#60A5FA', bg: 'rgba(96,165,250,0.12)' },
  UnderReview:   { label: 'Under Review',   color: '#FBBF24', bg: 'rgba(251,191,36,0.12)' },
  Approved:      { label: 'Approved',       color: '#34D399', bg: 'rgba(52,211,153,0.12)' },
  Paid:          { label: 'Paid',           color: '#22C55E', bg: 'rgba(34,197,94,0.12)'  },
  Rejected:      { label: 'Rejected',       color: '#F87171', bg: 'rgba(248,113,113,0.12)'},
  FraudSuspected:{ label: 'Fraud Suspect',  color: '#FB923C', bg: 'rgba(251,146,60,0.12)' },
  Active:        { label: 'Active',         color: '#22C55E', bg: 'rgba(34,197,94,0.12)'  },
  Expired:       { label: 'Expired',        color: '#6B7280', bg: 'rgba(107,114,128,0.12)'},
  Cancelled:     { label: 'Cancelled',      color: '#F87171', bg: 'rgba(248,113,113,0.12)'},
  PendingPayment:{ label: 'Pending',        color: '#FBBF24', bg: 'rgba(251,191,36,0.12)' },
};

export const CITIES = [
  'Delhi','Mumbai','Bangalore','Hyderabad','Chennai',
  'Pune','Kolkata','Jaipur','Ahmedabad','Lucknow',
];
