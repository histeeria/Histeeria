'use client';

import { useState } from 'react';
import { Clock, History, Search, Link2, Briefcase, DollarSign } from 'lucide-react';
import { Card } from '@/components/ui/Card';

export default function AppUsageTab() {
  const [activeFilter, setActiveFilter] = useState<'time' | 'watch' | 'account' | 'searches' | 'links' | 'jobs' | 'earnings'>('time');

  const filters = [
    { id: 'time' as const, label: 'Time Spent', icon: Clock },
    { id: 'watch' as const, label: 'Watch History', icon: History },
    { id: 'account' as const, label: 'Account History', icon: History },
    { id: 'searches' as const, label: 'Recent Searches', icon: Search },
    { id: 'links' as const, label: 'Link History', icon: Link2 },
    { id: 'jobs' as const, label: 'Recent Jobs', icon: Briefcase },
    { id: 'earnings' as const, label: 'Recent Earnings', icon: DollarSign },
  ];

  return (
    <div className="space-y-6">
      {/* Filters */}
      <div className="flex gap-2 overflow-x-auto scrollbar-hide pb-2">
        {filters.map((filter) => {
          const Icon = filter.icon;
          const isActive = activeFilter === filter.id;
          
          return (
            <button
              key={filter.id}
              onClick={() => setActiveFilter(filter.id)}
              className={`
                flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium whitespace-nowrap
                transition-all duration-200
                ${isActive
                  ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400'
                  : 'bg-white dark:bg-neutral-800 text-neutral-600 dark:text-neutral-400 hover:bg-neutral-100 dark:hover:bg-neutral-700'
                }
              `}
            >
              <Icon className="w-4 h-4" />
              <span>{filter.label}</span>
            </button>
          );
        })}
      </div>

      {/* Content */}
      <Card variant="glass" className="p-6">
        <div className="text-center py-12">
          {activeFilter === 'time' && (
            <div className="space-y-2">
              <p className="text-2xl font-bold text-purple-600 dark:text-purple-400">0h 0m</p>
              <p className="text-sm text-neutral-500 dark:text-neutral-400">Today</p>
            </div>
          )}
          {activeFilter !== 'time' && (
            <p className="text-neutral-500 dark:text-neutral-400">
              No {filters.find(f => f.id === activeFilter)?.label.toLowerCase()} yet
            </p>
          )}
        </div>
      </Card>
    </div>
  );
}

