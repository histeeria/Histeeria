'use client';

/**
 * Bottom Navigation Component
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Mobile bottom navigation bar
 * Minimal transparent design
 */

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '@/lib/utils';
import { Home, Search, PlusSquare, Compass, User as UserIcon } from 'lucide-react';
import { useUser } from '@/lib/hooks/useUser';
import { Avatar } from '@/components/ui/Avatar';

const navigation = [
  { name: 'Home', href: '/home', icon: Home },
  { name: 'Search', href: '/search', icon: Search },
  { name: 'Create', href: '/create', icon: PlusSquare, special: true },
  { name: 'Profile', href: '/profile', icon: UserIcon, useAvatar: true },
];

export function BottomNav() {
  const pathname = usePathname();
  const { user } = useUser();

  const isActive = (href: string) => pathname === href;

  return (
    <nav className="lg:hidden fixed bottom-0 left-0 right-0 h-14 md:h-14 z-50 bg-white/5 dark:bg-gray-900/5 backdrop-blur-md">
      <div className="h-full px-2 flex items-center justify-around">
        {navigation.map((item) => {
          const Icon = item.icon;
          const active = isActive(item.href);
          
          // Special handling for Profile tab (show user avatar)
          if (item.useAvatar) {
            return (
              <Link
                key={item.name}
                href={item.href}
                className={cn(
                  'flex flex-col items-center justify-center gap-0.5 px-3 py-1.5 rounded-lg transition-all duration-200 min-w-[60px] active:scale-95',
                  active
                    ? 'text-brand-purple-600 dark:text-brand-purple-400'
                    : 'text-neutral-500 dark:text-neutral-400'
                )}
              >
                <div className="relative flex items-center justify-center">
                  {user?.profile_picture ? (
                    <Avatar 
                      src={user.profile_picture} 
                      alt="Profile" 
                      fallback={user.display_name}
                      size="sm"
                      className="w-6 h-6"
                    />
                  ) : (
                    <Icon 
                      className={cn(
                        'transition-transform duration-200',
                        active ? 'w-6 h-6' : 'w-[22px] h-[22px]'
                      )} 
                      strokeWidth={active ? 2.5 : 2}
                    />
                  )}
                </div>
                <span className={cn(
                  'text-[10px] font-medium transition-colors',
                  active ? 'text-brand-purple-600 dark:text-brand-purple-400' : 'text-neutral-500 dark:text-neutral-400'
                )}>
                  {item.name}
                </span>
              </Link>
            );
          }

          return (
            <Link
              key={item.name}
              href={item.href}
              className={cn(
                'flex flex-col items-center justify-center gap-0.5 px-3 py-1.5 rounded-lg transition-all duration-200 min-w-[60px] active:scale-95',
                active
                  ? 'text-brand-purple-600 dark:text-brand-purple-400'
                  : 'text-neutral-500 dark:text-neutral-400'
              )}
            >
              <div className={cn(
                'relative flex items-center justify-center',
                item.special && !active && 'w-9 h-9 rounded-xl bg-brand-purple-600 text-white shadow-sm'
              )}>
                <Icon 
                  className={cn(
                    'transition-transform duration-200',
                    item.special 
                      ? 'w-5 h-5' 
                      : active 
                        ? 'w-6 h-6' 
                        : 'w-[22px] h-[22px]'
                  )} 
                  strokeWidth={active ? 2.5 : 2}
                />
              </div>
              <span className={cn(
                'text-[10px] font-medium transition-colors',
                active ? 'text-brand-purple-600 dark:text-brand-purple-400' : 'text-neutral-500 dark:text-neutral-400'
              )}>
                {item.name}
              </span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
