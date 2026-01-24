'use client';

/**
 * Sidebar Component
 * Created by: Hamza Hafeez - Founder & CEO of Asteria
 * 
 * Desktop left sidebar with navigation
 * Glassmorphic styling with iOS-inspired design
 */

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState } from 'react';
import { cn } from '@/lib/utils';
import {
  Home,
  Search,
 // Users,
 // Calendar,
 // Compass,
  MessageCircle,
  Bell,
  PlusSquare,
  User,
  Menu,
  Settings,
  Activity,
  Bookmark,
 // DollarSign,
  BarChart,
  Users2,
  SunMoon,
  Languages,
  AlertCircle,
  LogOut,
} from 'lucide-react';
import { useTheme } from '@/lib/contexts/ThemeContext';
import { useUser } from '@/lib/hooks/useUser';
import { useNotifications } from '@/lib/contexts/NotificationContext';
import { useUnreadMessages } from '@/lib/hooks/useUnreadMessages';
import { Avatar } from '@/components/ui/Avatar';
import { Badge } from '@/components/ui/Badge';

const navigationBase = [
  { name: 'Home', href: '/home', icon: Home },
  { name: 'Search', href: '/search', icon: Search },
  { name: 'Messages', href: '/messages', icon: MessageCircle, badge: 3 },
  { name: 'Notifications', href: '/notifications', icon: Bell },
  { name: 'Create', href: '/create', icon: PlusSquare },
  { name: 'Profile', href: '/profile', icon: User },
];

const moreMenu = [
  { name: 'Settings', href: '/settings', icon: Settings },
  { name: 'Your Activity', href: '/activity', icon: Activity },
  { name: 'Saved', href: '/saved', icon: Bookmark },
  { name: 'Account Summary', href: '/account', icon: BarChart },
  { name: 'Switch Profiles', href: '/switch-profile', icon: Users2 },
  { name: 'Switch Language', href: '/language', icon: Languages },
  { name: 'Report a Problem', href: '/report', icon: AlertCircle },
];

export function Sidebar() {
  const pathname = usePathname();
  const { theme, toggleTheme } = useTheme();
  const { user } = useUser();
  const { unreadCount } = useNotifications();
  const { unreadCount: unreadMessages } = useUnreadMessages();
  const [showMore, setShowMore] = useState(false);

  const isActive = (href: string) => pathname === href;

  // Add dynamic badges
  const navigation = navigationBase.map(item => {
    if (item.name === 'Notifications') {
      return { ...item, badge: unreadCount > 0 ? unreadCount : undefined };
    }
    if (item.name === 'Messages') {
      return { ...item, badge: unreadMessages > 0 ? unreadMessages : undefined };
    }
    return item;
  });

  return (
    <aside className="hidden lg:flex w-60 h-screen fixed top-0 left-0 z-40">
      <nav className="w-full h-full bg-white/80 dark:bg-gray-900/60 backdrop-blur-2xl border-r border-neutral-200/50 dark:border-neutral-800/50 flex flex-col py-6 px-4">
        {/* Logo - Redesigned Brand */}
        <Link href="/home" className="flex items-center gap-2.5 px-4 mb-8 group">
          <img 
            src="/assets/u.png" 
            alt="Upvista" 
            className="w-9 h-9 transition-transform group-hover:scale-110" 
          />
          <span className="text-2xl font-bold bg-gradient-to-r from-brand-purple-600 via-brand-purple-500 to-brand-purple-400 bg-clip-text text-transparent tracking-tight">
            Histeeria
          </span>
        </Link>

        {/* Navigation Items */}
        <div className="flex-1 space-y-1 overflow-y-auto scrollbar-hide">
          {navigation.map((item) => {
            const Icon = item.icon;
            const active = isActive(item.href);
            
            // Special handling for Profile tab (show user avatar)
            if (item.name === 'Profile' && user) {
              return (
                <Link
                  key={item.name}
                  href={item.href}
                  className={cn(
                    'flex items-center gap-4 px-4 py-3 rounded-xl font-medium transition-all duration-200',
                    active
                      ? 'bg-brand-purple-100 dark:bg-brand-purple-900/30 text-brand-purple-600 dark:text-brand-purple-400 border-l-4 border-brand-purple-600'
                      : 'text-neutral-700 dark:text-neutral-300 hover:bg-neutral-100 dark:hover:bg-neutral-800'
                  )}
                >
                  {user.profile_picture ? (
                    <Avatar 
                      src={user.profile_picture} 
                      alt="Profile" 
                      fallback={user.display_name}
                      size="sm"
                      className="w-6 h-6"
                    />
                  ) : (
                    <Icon className="w-6 h-6 flex-shrink-0" />
                  )}
                  <span className="flex-1">{item.name}</span>
                </Link>
              );
            }
            
            return (
              <Link
                key={item.name}
                href={item.href}
                className={cn(
                  'flex items-center gap-4 px-4 py-3 rounded-xl font-medium transition-all duration-200',
                  active
                    ? 'bg-brand-purple-100 dark:bg-brand-purple-900/30 text-brand-purple-600 dark:text-brand-purple-400 border-l-4 border-brand-purple-600'
                    : 'text-neutral-700 dark:text-neutral-300 hover:bg-neutral-100 dark:hover:bg-neutral-800'
                )}
              >
                <Icon className="w-6 h-6 flex-shrink-0" />
                <span className="flex-1">{item.name}</span>
                {item.badge !== undefined && (
                  <Badge variant="error" size="sm">
                    {item.badge > 99 ? '99+' : item.badge}
                  </Badge>
                )}
              </Link>
            );
          })}
        </div>

        {/* More Menu */}
        <div className="relative mt-4">
          <button
            onClick={() => setShowMore(!showMore)}
            className="w-full flex items-center gap-4 px-4 py-3 rounded-xl font-medium text-neutral-700 dark:text-neutral-300 hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors duration-200"
          >
            <Menu className="w-6 h-6" />
            <span>More</span>
          </button>

          {showMore && (
            <div className="absolute bottom-full left-0 right-0 mb-2 bg-white/90 dark:bg-gray-900/90 backdrop-blur-xl border border-neutral-200/50 dark:border-neutral-800/50 rounded-2xl shadow-2xl p-2 space-y-1">
              {moreMenu.map((item) => {
                const Icon = item.icon;
                return (
                  <Link
                    key={item.name}
                    href={item.href}
                    className="flex items-center gap-3 px-4 py-2.5 rounded-lg text-sm font-medium text-neutral-700 dark:text-neutral-300 hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors duration-200 text-left"
                  >
                    <Icon className="w-5 h-5 flex-shrink-0" />
                    <span className="flex-1">{item.name}</span>
                  </Link>
                );
              })}
              
              {/* Theme Toggle */}
              <button
                onClick={toggleTheme}
                className="w-full flex items-center gap-3 px-4 py-2.5 rounded-lg text-sm font-medium text-neutral-700 dark:text-neutral-300 hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors duration-200 text-left"
              >
                <SunMoon className="w-5 h-5 flex-shrink-0" />
                <span className="flex-1">Switch Theme ({theme})</span>
              </button>
              
              {/* Logout */}
              <button
                onClick={() => {
                  localStorage.removeItem('token');
                  window.location.href = '/auth';
                }}
                className="w-full flex items-center gap-3 px-4 py-2.5 rounded-lg text-sm font-medium text-error hover:bg-red-50 dark:hover:bg-red-950/30 transition-colors duration-200 text-left"
              >
                <LogOut className="w-5 h-5 flex-shrink-0" />
                <span className="flex-1">Logout</span>
              </button>
            </div>
          )}
        </div>
      </nav>
    </aside>
  );
}
