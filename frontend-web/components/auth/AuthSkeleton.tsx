'use client';

/**
 * Auth Skeleton Loader
 * Loading state for authentication pages
 */

export function AuthSkeleton() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-white">
      <div className="w-full max-w-md px-8 py-12">
        {/* Logo Skeleton */}
        <div className="mb-12 flex flex-col items-center gap-3">
          <div className="h-[70px] w-[70px] animate-pulse rounded-full bg-gray-200" />
          <div className="h-8 w-32 animate-pulse rounded bg-gray-200" />
        </div>

        {/* Title Skeleton */}
        <div className="mb-10">
          <div className="mx-auto h-10 w-64 animate-pulse rounded bg-gray-200" />
        </div>

        {/* Form Skeleton */}
        <div className="space-y-5">
          {[1, 2, 3].map((i) => (
            <div key={i} className="relative">
              <div className="h-14 w-full animate-pulse rounded-2xl bg-gray-200" />
            </div>
          ))}
        </div>

        {/* Button Skeleton */}
        <div className="mt-6">
          <div className="h-14 w-full animate-pulse rounded-2xl bg-gray-300" />
        </div>

        {/* Social Buttons Skeleton */}
        <div className="mt-8 space-y-3">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-12 w-full animate-pulse rounded-2xl bg-gray-100" />
          ))}
        </div>
      </div>
    </div>
  );
}
