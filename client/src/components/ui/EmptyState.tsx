import { type LucideIcon } from 'lucide-react';

interface EmptyStateProps {
  icon?: LucideIcon;
  emoji?: string;
  title: string;
  description?: string;
  action?: React.ReactNode;
}

export default function EmptyState({ icon: Icon, emoji, title, description, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <div className="w-16 h-16 rounded-2xl bg-white/[0.03] border border-white/6 flex items-center justify-center mb-4">
        {emoji
          ? <span className="text-2xl">{emoji}</span>
          : Icon && <Icon className="w-7 h-7 text-gray-500" />
        }
      </div>
      <h3 className="text-base font-semibold text-white mb-2">{title}</h3>
      {description && <p className="text-sm text-gray-500 max-w-xs leading-relaxed mb-4">{description}</p>}
      {action}
    </div>
  );
}
