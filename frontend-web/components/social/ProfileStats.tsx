'use client';

/**
 * ProfileStats Component
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Displays profile stats with privacy controls
 */

import { useEffect, useState } from 'react';
import { relationshipAPI } from '@/lib/api';

interface ProfileStatsProps {
  userId?: string;
  isOwnProfile?: boolean;
  profileData?: any; // For direct stats from profile
  statVisibility?: { [key: string]: boolean };
  onStatClick?: (type: StatType) => void;
}

type StatType = 'posts' | 'projects' | 'followers' | 'following' | 'connections' | 'collaborators';

interface AllStats {
  posts_count: number;
  projects_count: number;
  followers_count: number;
  following_count: number;
  connections_count: number;
  collaborators_count: number;
}

export default function ProfileStats({ 
  userId, 
  isOwnProfile = false, 
  profileData,
  statVisibility,
  onStatClick 
}: ProfileStatsProps) {
  const [stats, setStats] = useState<AllStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        setLoading(true);
        
        console.log('[ProfileStats] Rendering with statVisibility:', statVisibility);
        
        let allStats: AllStats = {
          posts_count: 0,
          projects_count: 0,
          followers_count: 0,
          following_count: 0,
          connections_count: 0,
          collaborators_count: 0,
        };

        // Get posts and projects from profile data
        if (profileData) {
          allStats.posts_count = profileData.posts_count || 0;
          allStats.projects_count = profileData.projects_count || 0;
          allStats.followers_count = profileData.followers_count || 0;
          allStats.following_count = profileData.following_count || 0;
        }

        // Fetch relationship stats if own profile
        if (isOwnProfile) {
          try {
            const response = await relationshipAPI.getRelationshipStats();
            if (response.success && response.stats) {
              allStats.followers_count = response.stats.followers_count;
              allStats.following_count = response.stats.following_count;
              allStats.connections_count = response.stats.connections_count;
              allStats.collaborators_count = response.stats.collaborators_count;
            }
          } catch (err) {
            console.error('Failed to fetch relationship stats:', err);
          }
        }

        setStats(allStats);
      } catch (err) {
        console.error('Failed to fetch stats:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchStats();
  }, [userId, isOwnProfile, profileData, statVisibility]);

  if (loading) {
    return (
      <div className="flex gap-4 py-4 flex-wrap justify-center">
        {[1, 2, 3, 4].map((i) => (
          <div key={i} className="flex flex-col items-center min-w-[80px]">
            <div className="h-6 w-12 bg-neutral-200 dark:bg-neutral-700 rounded animate-pulse mb-1" />
            <div className="h-4 w-20 bg-neutral-200 dark:bg-neutral-700 rounded animate-pulse" />
          </div>
        ))}
      </div>
    );
  }

  if (!stats) return null;

  // All available stats
  const allStatItems: Array<{ count: number; label: string; type: StatType }> = [
    { count: stats.posts_count, label: 'Posts', type: 'posts' },
    { count: stats.projects_count, label: 'Projects', type: 'projects' },
    { count: stats.followers_count, label: 'Followers', type: 'followers' },
    { count: stats.following_count, label: 'Following', type: 'following' },
    { count: stats.connections_count, label: 'Connections', type: 'connections' },
    { count: stats.collaborators_count, label: 'Collaborators', type: 'collaborators' },
  ];

  // Filter stats based on visibility settings
  const visibleStats = allStatItems.filter(item => {
    // If no visibility settings, show all
    if (!statVisibility) return true;
    // Check if this stat is visible (default to true if not specified)
    return statVisibility[item.type] !== false;
  });

  // Ensure at least 3 stats are shown
  const statsToShow = visibleStats.length >= 3 ? visibleStats : allStatItems.slice(0, 3);

  return (
    <div className="py-3 border-y border-neutral-200 dark:border-neutral-700">
      {/* Mobile: 2x3 Grid */}
      <div className="grid grid-cols-3 gap-2 md:hidden">
        {statsToShow.map((item) => (
          <button
            key={item.type}
            onClick={() => onStatClick && onStatClick(item.type)}
            className="flex flex-col items-center hover:bg-neutral-100 dark:hover:bg-neutral-800 px-2 py-1.5 rounded-lg transition-colors"
          >
            <span className="text-base font-bold text-neutral-900 dark:text-neutral-50">
              {item.count}
            </span>
            <span className="text-xs text-neutral-600 dark:text-neutral-400">
              {item.label}
            </span>
          </button>
        ))}
      </div>
      
      {/* Desktop: Horizontal flex */}
      <div className="hidden md:flex gap-4 justify-center">
        {statsToShow.map((item) => (
          <button
            key={item.type}
            onClick={() => onStatClick && onStatClick(item.type)}
            className="flex flex-col items-center hover:bg-neutral-100 dark:hover:bg-neutral-800 px-3 py-1 rounded-lg transition-colors min-w-[80px]"
          >
            <span className="text-xl font-bold text-neutral-900 dark:text-neutral-50">
              {item.count}
            </span>
            <span className="text-sm text-neutral-600 dark:text-neutral-400">
              {item.label}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}

