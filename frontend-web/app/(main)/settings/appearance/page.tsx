'use client';

/**
 * Appearance Settings Page
 * Instagram-style: transparent, full-width, no borders
 */

import { useRouter } from 'next/navigation';
import { MainLayout } from '@/components/layout/MainLayout';
import { ArrowLeft } from 'lucide-react';
import { useTheme } from '@/lib/contexts/ThemeContext';

export default function AppearanceSettingsPage() {
  const router = useRouter();
  const { theme, setTheme } = useTheme();

  return (
    <MainLayout>
      <div className="min-h-screen bg-white dark:bg-neutral-950">
        <div className="w-full">
          {/* Header */}
          <div className="flex items-center gap-4 px-4 py-4 border-b border-neutral-200 dark:border-neutral-800">
            <button
              onClick={() => router.push('/settings')}
              className="p-1 -ml-1 rounded-full transition-colors"
            >
              <ArrowLeft className="w-6 h-6 text-neutral-900 dark:text-neutral-50" />
            </button>
            <h1 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50">
              Appearance
            </h1>
          </div>

          <div className="w-full px-4 py-6">
            <h3 className="text-base font-semibold text-neutral-900 dark:text-neutral-50 mb-4">
              Theme
            </h3>
            <div className="grid grid-cols-3 gap-3">
              {/* Light Theme */}
              <button
                onClick={() => setTheme('light')}
                className={`p-3 rounded-lg border-2 transition-all cursor-pointer ${
                  theme === 'light'
                    ? 'border-brand-purple-600 bg-brand-purple-50 dark:bg-brand-purple-900/20'
                    : 'border-neutral-200 dark:border-neutral-800 hover:border-neutral-300 dark:hover:border-neutral-700'
                }`}
              >
                <div className="w-full h-16 bg-white rounded-md mb-2 border border-neutral-200" />
                <p className="font-medium text-neutral-900 dark:text-neutral-50 text-sm">Light</p>
              </button>
              
              {/* Dark Theme */}
              <button
                onClick={() => setTheme('dark')}
                className={`p-3 rounded-lg border-2 transition-all cursor-pointer ${
                  theme === 'dark'
                    ? 'border-brand-purple-600 bg-brand-purple-50 dark:bg-brand-purple-900/20'
                    : 'border-neutral-200 dark:border-neutral-800 hover:border-neutral-300 dark:hover:border-neutral-700'
                }`}
              >
                <div className="w-full h-16 bg-neutral-900 rounded-md mb-2 border border-neutral-700" />
                <p className="font-medium text-neutral-900 dark:text-neutral-50 text-sm">Dark</p>
              </button>
              
              {/* iOS Theme */}
              <button
                onClick={() => setTheme('ios')}
                className={`p-3 rounded-lg border-2 transition-all cursor-pointer ${
                  theme === 'ios'
                    ? 'border-brand-purple-600 bg-brand-purple-50 dark:bg-brand-purple-900/20'
                    : 'border-neutral-200 dark:border-neutral-800 hover:border-neutral-300 dark:hover:border-neutral-700'
                }`}
              >
                <div className="w-full h-16 rounded-md mb-2 border border-purple-200/40 relative overflow-hidden" 
                  style={{
                    background: 'linear-gradient(135deg, #EDE7F6 0%, #D1C4E9 30%, #B39DDB 60%, #9575CD 90%, #7E57C2 100%)',
                  }}
                >
                  <div className="absolute inset-0" 
                    style={{
                      background: 'linear-gradient(135deg, rgba(255,255,255,0.5) 0%, rgba(255,255,255,0.15) 40%, rgba(255,255,255,0) 70%)',
                    }}
                  />
                </div>
                <p className="font-medium text-neutral-900 dark:text-neutral-50 text-sm">iOS</p>
              </button>
            </div>
            
            <p className="text-xs text-neutral-500 dark:text-neutral-400 mt-4">
              {theme === 'light' && 'Clean, minimal light theme'}
              {theme === 'dark' && 'Professional dark theme'}
              {theme === 'ios' && 'Premium glassmorphism design'}
            </p>
          </div>
        </div>
      </div>
    </MainLayout>
  );
}
