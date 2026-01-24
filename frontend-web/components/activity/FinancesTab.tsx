'use client';

import { useState } from 'react';
import { Briefcase, Building2, DollarSign, CreditCard, Star } from 'lucide-react';
import { Card } from '@/components/ui/Card';

export default function FinancesTab() {
  const [activeFilter, setActiveFilter] = useState<'projects' | 'jobs' | 'earnings' | 'spendings' | 'reviews'>('projects');

  const filters = [
    { id: 'projects' as const, label: 'Your Projects', icon: Briefcase },
    { id: 'jobs' as const, label: 'Your Jobs', icon: Building2 },
    { id: 'earnings' as const, label: 'Your Earnings', icon: DollarSign },
    { id: 'spendings' as const, label: 'Your Spendings', icon: CreditCard },
    { id: 'reviews' as const, label: 'Your Reviews', icon: Star },
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
          <p className="text-neutral-500 dark:text-neutral-400">
            {activeFilter === 'earnings' && (
              <div className="space-y-2">
                <p className="text-2xl font-bold text-purple-600 dark:text-purple-400">$0.00</p>
                <p className="text-sm">Total earnings</p>
              </div>
            )}
            {activeFilter !== 'earnings' && (
              <p>No {filters.find(f => f.id === activeFilter)?.label.toLowerCase()} yet</p>
            )}
          </p>
        </div>
      </Card>
    </div>
  );
}

