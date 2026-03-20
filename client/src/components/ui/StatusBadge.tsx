import { STATUS_META } from '@/lib/utils';

interface StatusBadgeProps {
  status: string;
  size?: 'sm' | 'md';
}

export default function StatusBadge({ status, size = 'md' }: StatusBadgeProps) {
  const meta = STATUS_META[status] ?? { label: status, color: '#6B7280', bg: 'rgba(107,114,128,0.12)' };
  return (
    <span
      className={`inline-flex items-center gap-1.5 font-medium rounded-full ${size === 'sm' ? 'text-[11px] px-2 py-0.5' : 'text-xs px-2.5 py-1'}`}
      style={{ color: meta.color, background: meta.bg }}
    >
      <span className="w-1.5 h-1.5 rounded-full flex-shrink-0" style={{ background: meta.color }} />
      {meta.label}
    </span>
  );
}
