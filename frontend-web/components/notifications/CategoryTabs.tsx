'use client';

/**
 * Category Tabs Component
 * Professional category filtering for notifications
 * Mobile-optimized to fit without scrolling
 */

import { Inbox, Users, FolderKanban, Building2 } from 'lucide-react';

interface CategoryTabsProps {
  activeCategory: string;
  onCategoryChange: (category: string) => void;
  categoryCounts: Record<string, number>;
  totalCount: number;
}

const categories = [
  { id: 'all', label: 'All', Icon: Inbox },
  { id: 'social', label: 'Social', Icon: Users },
  { id: 'projects', label: 'Projects', Icon: FolderKanban },
  { id: 'communities', label: 'Communities', Icon: Building2 },
];

export default function CategoryTabs({
  activeCategory,
  onCategoryChange,
  categoryCounts,
  totalCount,
}: CategoryTabsProps) {
  const getCount = (categoryId: string) => {
    if (categoryId === 'all') return totalCount;
    return categoryCounts[categoryId] || 0;
  };

  return (
    <div className="border-b border-neutral-200 dark:border-neutral-800">
      <div className="flex justify-around sm:justify-start sm:gap-0">
        {categories.map((category) => {
          const count = getCount(category.id);
          const isActive = activeCategory === category.id;
          const Icon = category.Icon;

          return (
            <button
              key={category.id}
              onClick={() => onCategoryChange(category.id)}
              className={`
                relative flex flex-col sm:flex-row items-center gap-1 sm:gap-2 px-3 sm:px-6 py-2.5 sm:py-3.5 text-xs sm:text-sm font-medium transition-all flex-1 sm:flex-none
                ${isActive
                  ? 'text-brand-purple-600 dark:text-brand-purple-400 border-b-2 border-brand-purple-600 dark:border-brand-purple-400'
                  : 'text-neutral-600 dark:text-neutral-400 hover:text-neutral-900 dark:hover:text-neutral-200 hover:bg-neutral-50 dark:hover:bg-neutral-800/50'
                }
              `}
            >
              <Icon className="w-4 h-4 sm:w-4 sm:h-4" />
              <span className="hidden sm:inline">{category.label}</span>
              <span className="sm:hidden text-[10px]">{category.label}</span>
              
              {count > 0 && (
                <span className={`
                  absolute top-1 right-1 sm:static sm:ml-1 min-w-[16px] sm:min-w-[20px] h-4 sm:h-5 px-1 sm:px-1.5 flex items-center justify-center rounded-full text-[10px] sm:text-xs font-semibold
                  ${isActive
                    ? 'bg-brand-purple-600 dark:bg-brand-purple-500 text-white'
                    : 'bg-red-500 text-white'
                  }
                `}>
                  {count > 99 ? '99+' : count}
                </span>
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
}


