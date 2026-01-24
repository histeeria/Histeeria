'use client';

import { useState } from 'react';
import { Trash2, Archive, RotateCw } from 'lucide-react';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';

export default function ArchivedTab() {
  const [activeFilter, setActiveFilter] = useState<'deleted' | 'archived'>('deleted');

  return (
    <div className="space-y-6">
      {/* Filters */}
      <div className="flex gap-2">
        <button
          onClick={() => setActiveFilter('deleted')}
          className={`
            flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium
            transition-all duration-200
            ${activeFilter === 'deleted'
              ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400'
              : 'bg-white dark:bg-neutral-800 text-neutral-600 dark:text-neutral-400 hover:bg-neutral-100 dark:hover:bg-neutral-700'
            }
          `}
        >
          <Trash2 className="w-4 h-4" />
          <span>Recently Deleted</span>
        </button>
        <button
          onClick={() => setActiveFilter('archived')}
          className={`
            flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium
            transition-all duration-200
            ${activeFilter === 'archived'
              ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400'
              : 'bg-white dark:bg-neutral-800 text-neutral-600 dark:text-neutral-400 hover:bg-neutral-100 dark:hover:bg-neutral-700'
            }
          `}
        >
          <Archive className="w-4 h-4" />
          <span>Archive</span>
        </button>
      </div>

      {/* Content */}
      <Card variant="glass" className="p-6">
        <div className="text-center py-12">
          <p className="text-neutral-500 dark:text-neutral-400">
            {activeFilter === 'deleted' 
              ? 'No recently deleted content'
              : 'No archived content'
            }
          </p>
          {activeFilter === 'deleted' && (
            <p className="text-sm text-neutral-400 dark:text-neutral-500 mt-2">
              Deleted content can be restored within 30 days
            </p>
          )}
        </div>
      </Card>
    </div>
  );
}

