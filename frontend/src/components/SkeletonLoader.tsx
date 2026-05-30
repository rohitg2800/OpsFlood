import React from 'react';

interface SkeletonLoaderProps {
  type?: 'card' | 'chart' | 'table' | 'text' | 'circle' | 'gauge';
  count?: number;
}

export const SkeletonLoader: React.FC<SkeletonLoaderProps> = ({
  type = 'card',
  count = 1,
}) => {
  const renderSkeleton = () => {
    switch (type) {
      case 'card':
        return (
          <div className="bg-black/25 rounded-[2rem] border border-white/10 ring-1 ring-white/5 backdrop-blur-xl p-6 space-y-4">
            <div className="flex items-center justify-between">
              <div className="skeleton h-6 w-32 rounded-lg" />
              <div className="skeleton h-4 w-20 rounded-lg" />
            </div>
            <div className="skeleton h-48 w-full rounded-2xl" />
            <div className="grid grid-cols-3 gap-4">
              <div className="skeleton h-16 rounded-xl" />
              <div className="skeleton h-16 rounded-xl" />
              <div className="skeleton h-16 rounded-xl" />
            </div>
          </div>
        );

      case 'chart':
        return (
          <div className="bg-black/25 rounded-[2rem] border border-white/10 ring-1 ring-white/5 backdrop-blur-xl p-6 space-y-4">
            <div className="flex items-center justify-between">
              <div className="skeleton h-6 w-40 rounded-lg" />
              <div className="skeleton h-4 w-24 rounded-lg" />
            </div>
            <div className="skeleton h-64 w-full rounded-2xl" />
            <div className="flex justify-between">
              <div className="skeleton h-4 w-16 rounded-lg" />
              <div className="skeleton h-4 w-16 rounded-lg" />
              <div className="skeleton h-4 w-16 rounded-lg" />
              <div className="skeleton h-4 w-16 rounded-lg" />
              <div className="skeleton h-4 w-16 rounded-lg" />
            </div>
          </div>
        );

      case 'table':
        return (
          <div className="bg-black/25 rounded-[2rem] border border-white/10 ring-1 ring-white/5 backdrop-blur-xl overflow-hidden">
            <div className="p-6 border-b border-white/10">
              <div className="skeleton h-6 w-48 rounded-lg" />
            </div>
            <div className="divide-y divide-white/5">
              {[1, 2, 3, 4, 5].map((i) => (
                <div key={i} className="p-4 flex items-center justify-between">
                  <div className="skeleton h-4 w-32 rounded-lg" />
                  <div className="skeleton h-4 w-24 rounded-lg" />
                  <div className="skeleton h-4 w-20 rounded-lg" />
                  <div className="skeleton h-4 w-16 rounded-lg" />
                </div>
              ))}
            </div>
          </div>
        );

      case 'text':
        return (
          <div className="space-y-3">
            <div className="skeleton h-4 w-full rounded-lg" />
            <div className="skeleton h-4 w-5/6 rounded-lg" />
            <div className="skeleton h-4 w-4/6 rounded-lg" />
          </div>
        );

      case 'circle':
        return (
          <div className="flex items-center gap-4">
            <div className="skeleton w-12 h-12 rounded-full" />
            <div className="space-y-2 flex-1">
              <div className="skeleton h-4 w-3/4 rounded-lg" />
              <div className="skeleton h-3 w-1/2 rounded-lg" />
            </div>
          </div>
        );

      case 'gauge':
        return (
          <div className="bg-black/25 rounded-[2rem] border border-white/10 ring-1 ring-white/5 backdrop-blur-xl p-6 flex items-center justify-center">
            <div className="relative w-48 h-48">
              <div className="skeleton w-full h-full rounded-full" />
              <div className="absolute inset-0 flex flex-col items-center justify-center">
                <div className="skeleton h-10 w-20 rounded-lg mb-2" />
                <div className="skeleton h-3 w-16 rounded-lg" />
              </div>
            </div>
          </div>
        );

      default:
        return null;
    }
  };

  return (
    <>
      {Array.from({ length: count }).map((_, idx) => (
        <div key={idx} className="animate-fade-in">
          {renderSkeleton()}
        </div>
      ))}
    </>
  );
};

export default SkeletonLoader;
