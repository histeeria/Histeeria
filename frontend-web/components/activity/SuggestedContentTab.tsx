'use client';

import { useState } from 'react';
import { X, Check } from 'lucide-react';
import { Card } from '@/components/ui/Card';

export default function SuggestedContentTab() {
  const [activeFilter, setActiveFilter] = useState<'not-interested' | 'interested'>('not-interested');

  return (
    <div className="space-y-6">
      {/* Filters */}
      <div className="flex gap-2">
        <button
          onClick={() => setActiveFilter('not-interested')}
          className={`
            flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium
            transition-all duration-200
            ${activeFilter === 'not-interested'
              ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400'
              : 'bg-white dark:bg-neutral-800 text-neutral-600 dark:text-neutral-400 hover:bg-neutral-100 dark:hover:bg-neutral-700'
            }
          `}
        >
          <X className="w-4 h-4" />
          <span>Not Interested</span>
        </button>
        <button
          onClick={() => setActiveFilter('interested')}
          className={`
            flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium
            transition-all duration-200
            ${activeFilter === 'interested'
              ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400'
              : 'bg-white dark:bg-neutral-800 text-neutral-600 dark:text-neutral-400 hover:bg-neutral-100 dark:hover:bg-neutral-700'
            }
          `}
        >
          <Check className="w-4 h-4" />
          <span>Interested</span>
        </button>
      </div>

      {/* Content */}
      <Card variant="glass" className="p-6">
        <div className="text-center py-12">
          <p className="text-neutral-500 dark:text-neutral-400">
            {activeFilter === 'not-interested'
              ? 'No dismissed suggestions'
              : 'No saved suggestions'
            }
          </p>
        </div>
      </Card>
    </div>
  );
}

