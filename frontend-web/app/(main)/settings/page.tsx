'use client';

/**
 * Settings Main Page - Instagram-style
 * Transparent, full-width, no borders
 */

import { useRouter } from 'next/navigation';
import { MainLayout } from '@/components/layout/MainLayout';
import { 
  User, 
  Lock, 
  Shield, 
  Globe, 
  Palette, 
  HelpCircle,
  Download,
  Smartphone,
  Bell,
  ChevronRight
} from 'lucide-react';

const settingsSections = [
  { id: 'account', name: 'Account', icon: User, path: '/settings/account' },
  { id: 'security', name: 'Security', icon: Lock, path: '/settings/security' },
  { id: 'privacy', name: 'Privacy', icon: Shield, path: '/settings/privacy' },
  { id: 'notifications', name: 'Notifications', icon: Bell, path: '/settings/notifications' },
  { id: 'sessions', name: 'Active Sessions', icon: Smartphone, path: '/settings/sessions' },
  { id: 'data', name: 'Data & Privacy', icon: Download, path: '/settings/data' },
  { id: 'appearance', name: 'Appearance', icon: Palette, path: '/settings/appearance' },
  { id: 'language', name: 'Language', icon: Globe, path: '/settings/language' },
  { id: 'help', name: 'Help & Support', icon: HelpCircle, path: '/settings/help' },
];

export default function SettingsPage() {
  const router = useRouter();

  return (
    <MainLayout>
      <div className="min-h-screen bg-white dark:bg-neutral-950">
        <div className="w-full">
          {/* Header */}
          <div className="px-4 py-4 border-b border-neutral-200 dark:border-neutral-800">
            <h1 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50">
              Settings
            </h1>
          </div>

          {/* Settings List - Full Width */}
          <div className="w-full">
            {settingsSections.map((section, index) => {
              const Icon = section.icon;
              
              return (
                <div key={section.id}>
                  <button
                    onClick={() => router.push(section.path)}
                    className="w-full flex items-center justify-between px-4 py-4 transition-colors cursor-pointer text-left"
                  >
                    <div className="flex items-center gap-3">
                      <Icon className="w-5 h-5 text-neutral-900 dark:text-neutral-50" />
                      <span className="text-base font-normal text-neutral-900 dark:text-neutral-50">
                        {section.name}
                      </span>
                    </div>
                    <ChevronRight className="w-5 h-5 text-neutral-400" />
                  </button>
                  {index < settingsSections.length - 1 && (
                    <div className="h-px bg-neutral-200 dark:bg-neutral-800 ml-14" />
                  )}
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </MainLayout>
  );
}
