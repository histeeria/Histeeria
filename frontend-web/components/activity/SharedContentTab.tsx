'use client';

import { useState } from 'react';
import { FileText, Newspaper, Video, Briefcase, Building2 } from 'lucide-react';
import { Post, postsAPI } from '@/lib/api/posts';
import PostCard from '@/components/posts/PostCard';
import { Card } from '@/components/ui/Card';
import { Loader2 } from 'lucide-react';

export default function SharedContentTab() {
  const [activeFilter, setActiveFilter] = useState<'posts' | 'articles' | 'reels' | 'projects' | 'jobs'>('posts');
  const [loading, setLoading] = useState(false);
  const [posts, setPosts] = useState<Post[]>([]);

  const filters = [
    { id: 'posts' as const, label: 'Your Posts', icon: FileText },
    { id: 'articles' as const, label: 'Your Articles', icon: Newspaper },
    { id: 'reels' as const, label: 'Your Reels', icon: Video },
    { id: 'projects' as const, label: 'Your Projects', icon: Briefcase },
    { id: 'jobs' as const, label: 'Your Jobs', icon: Building2 },
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
        {loading ? (
          <div className="flex justify-center py-12">
            <Loader2 className="w-6 h-6 animate-spin text-purple-600" />
          </div>
        ) : posts.length === 0 ? (
          <div className="text-center py-12">
            <p className="text-neutral-500 dark:text-neutral-400">
              No {filters.find(f => f.id === activeFilter)?.label.toLowerCase()} yet
            </p>
          </div>
        ) : (
          <div className="space-y-4">
            {posts.map((post) => (
              <PostCard key={post.id} post={post} />
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}

