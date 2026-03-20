export function SkeletonCard({ className = '' }: { className?: string }) {
  return (
    <div className={`bg-dark-card border border-white/6 rounded-2xl p-5 space-y-3 ${className}`}>
      <div className="flex items-center justify-between">
        <div className="shimmer h-4 w-28 rounded-lg" />
        <div className="shimmer h-8 w-8 rounded-xl" />
      </div>
      <div className="shimmer h-8 w-32 rounded-lg" />
      <div className="shimmer h-3 w-full rounded" />
      <div className="shimmer h-3 w-2/3 rounded" />
    </div>
  );
}

export function SkeletonRow({ className = '' }: { className?: string }) {
  return (
    <div className={`flex items-center gap-4 p-4 ${className}`}>
      <div className="shimmer w-10 h-10 rounded-xl flex-shrink-0" />
      <div className="flex-1 space-y-2">
        <div className="shimmer h-3.5 w-40 rounded" />
        <div className="shimmer h-3 w-24 rounded" />
      </div>
      <div className="shimmer h-6 w-20 rounded-full" />
    </div>
  );
}

export function SkeletonPage() {
  return (
    <div className="space-y-6 animate-pulse">
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {[...Array(4)].map((_, i) => <SkeletonCard key={i} />)}
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2 bg-dark-card border border-white/6 rounded-2xl p-5 h-64" />
        <div className="bg-dark-card border border-white/6 rounded-2xl p-5 h-64" />
      </div>
    </div>
  );
}
