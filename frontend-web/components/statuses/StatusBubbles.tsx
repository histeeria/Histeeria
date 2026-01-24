'use client';

/**
 * Status Bubbles Component
 * Instagram-like horizontal scrollable status bubbles
 * Created by: Hamza Hafeez - Founder & CEO of Histeeria
 */

import { useEffect, useState } from 'react';
import { Plus } from 'lucide-react';
import { Avatar } from '@/components/ui/Avatar';
import { useUser } from '@/lib/hooks/useUser';
import { getStatusesForFeed, getUserStatuses, type Status } from '@/lib/api/statuses';
import { cn } from '@/lib/utils';
import { motion } from 'framer-motion';

interface StatusBubblesProps {
  onStatusClick: (status: Status, allStatuses: Status[]) => void;
  onCreateClick: () => void;
}

interface StatusUser {
  id: string;
  username: string;
  display_name: string;
  profile_picture?: string;
  statuses: Status[];
  hasUnviewed: boolean;
}

export function StatusBubbles({ onStatusClick, onCreateClick }: StatusBubblesProps) {
  const { user } = useUser();
  const [statusUsers, setStatusUsers] = useState<StatusUser[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadStatuses();
  }, []);

  // Listen for status creation events to refresh
  useEffect(() => {
    const handleStatusCreated = () => {
      loadStatuses();
    };

    window.addEventListener('status_created', handleStatusCreated);
    return () => window.removeEventListener('status_created', handleStatusCreated);
  }, []);

  const loadStatuses = async () => {
    try {
      setLoading(true);
      const statuses = await getStatusesForFeed();

      // Group statuses by user
      const userMap = new Map<string, StatusUser>();

      // Add own statuses first if user exists
      if (user) {
        try {
          const ownStatuses = await getUserStatuses(user.id);
          if (ownStatuses.length > 0) {
            userMap.set(user.id, {
              id: user.id,
              username: user.username || '',
              display_name: user.display_name || '',
              profile_picture: user.profile_picture || undefined,
              statuses: ownStatuses,
              hasUnviewed: false,
            });
          }
        } catch (err) {
          console.error('Failed to load own statuses:', err);
        }
      }

      // Group other users' statuses
      statuses.forEach((status) => {
        if (!status.author) return;

        if (!userMap.has(status.author.id)) {
          userMap.set(status.author.id, {
            id: status.author.id,
            username: status.author.username,
            display_name: status.author.display_name,
            profile_picture: status.author.profile_picture,
            statuses: [],
            hasUnviewed: false,
          });
        }

        const statusUser = userMap.get(status.author.id)!;
        statusUser.statuses.push(status);
        if (!status.is_viewed) {
          statusUser.hasUnviewed = true;
        }
      });

      // Sort statuses by creation time (newest first)
      userMap.forEach((statusUser) => {
        statusUser.statuses.sort((a, b) =>
          new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
        );
      });

      // Convert to array and sort: own statuses first, then by hasUnviewed, then by newest status
      const sortedUsers = Array.from(userMap.values()).sort((a, b) => {
        // Own statuses first
        if (a.id === user?.id) return -1;
        if (b.id === user?.id) return 1;

        // Unviewed statuses next
        if (a.hasUnviewed && !b.hasUnviewed) return -1;
        if (!a.hasUnviewed && b.hasUnviewed) return 1;

        // Then by newest status
        const aNewest = a.statuses[0]?.created_at || '';
        const bNewest = b.statuses[0]?.created_at || '';
        return new Date(bNewest).getTime() - new Date(aNewest).getTime();
      });

      setStatusUsers(sortedUsers);
    } catch (error) {
      console.error('Failed to load statuses:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleStatusClick = (statusUser: StatusUser) => {
    if (statusUser.statuses.length > 0) {
      onStatusClick(statusUser.statuses[0], statusUser.statuses);
    }
  };

  if (loading) {
    return (
      <div className="flex gap-3 px-4 py-3 overflow-x-auto scrollbar-hide">
        {[...Array(5)].map((_, i) => (
          <div key={i} className="flex-shrink-0 flex flex-col items-center gap-1.5">
            <div className="w-16 h-16 rounded-full bg-gray-200 dark:bg-gray-800" />
            <div className="h-3 w-12 bg-gray-200 dark:bg-gray-800 rounded" />
          </div>
        ))}
      </div>
    );
  }

  if (statusUsers.length === 0) {
    return (
      <div className="px-4 py-3">
        <div className="flex gap-3">
          {/* Create Status Button */}
          {user && (
            <button
              onClick={onCreateClick}
              className="flex-shrink-0 flex flex-col items-center gap-1.5 group"
            >
              <div className="relative">
                <Avatar
                  src={user.profile_picture}
                  alt={user.display_name || 'You'}
                  fallback={user.display_name || 'You'}
                  size="xl"
                  className="border-2 border-dashed border-neutral-300 dark:border-neutral-700 group-hover:border-brand-purple-500 transition-colors"
                />
                <div className="absolute bottom-0 right-0 w-6 h-6 bg-brand-purple-600 rounded-full flex items-center justify-center border-2 border-white dark:border-gray-900">
                  <Plus className="w-4 h-4 text-white" />
                </div>
              </div>
              <span className="text-[10px] font-medium text-neutral-600 dark:text-neutral-400 truncate max-w-[64px]">
                Your Status
              </span>
            </button>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="flex gap-3 px-4 py-3 overflow-x-auto scrollbar-hide">
      {/* My Status Bubble */}
      {user && (
        <motion.div
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: 1, scale: 1 }}
          className="flex-shrink-0 flex flex-col items-center gap-1.5 group relative"
        >
          <div className="relative">
            <button
              onClick={() => {
                const myStatusUser = statusUsers.find(u => u.id === user.id);
                if (myStatusUser) {
                  handleStatusClick(myStatusUser);
                } else {
                  onCreateClick();
                }
              }}
              className="relative block"
            >
              {/* Gradient Ring if has status */}
              <div
                className={cn(
                  "rounded-full p-[1.5px] w-[68px] h-[68px] flex items-center justify-center transition-all duration-300",
                  statusUsers.some(u => u.id === user.id)
                    ? "group-hover:shadow-[0_0_12px_rgba(168,85,247,0.5)]"
                    : "border-2 border-dashed border-neutral-300 dark:border-neutral-700"
                )}
                style={statusUsers.some(u => u.id === user.id) ? {
                  background: 'conic-gradient(from 0deg, #a855f7, #d946ef, #fb923c, #a855f7)'
                } : undefined}
              >
                <div className="rounded-full bg-white dark:bg-gray-900 p-[2px] w-full h-full flex items-center justify-center">
                  <Avatar
                    src={user.profile_picture}
                    alt="Your Status"
                    fallback="You"
                    size="xl"
                    className=""
                  />
                </div>
              </div>
            </button>

            {/* Plus Icon Logic */}
            {statusUsers.some(u => u.id === user.id) ? (
              // If status exists, show small + button to add more
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onCreateClick();
                }}
                className="absolute bottom-0 right-0 w-5 h-5 bg-brand-purple-600 rounded-full flex items-center justify-center border-[1.5px] border-white dark:border-gray-900 shadow-sm hover:scale-110 transition-transform z-10"
              >
                <Plus className="w-3 h-3 text-white" />
              </button>
            ) : (
              // If no status, show + indicator (part of main button)
              <div className="absolute bottom-0 right-0 w-6 h-6 bg-brand-purple-600 rounded-full flex items-center justify-center border-2 border-white dark:border-gray-900 text-white pointer-events-none">
                <Plus className="w-4 h-4" />
              </div>
            )}
          </div>

          <span className="text-[10px] font-medium text-neutral-600 dark:text-neutral-400 truncate max-w-[64px]">
            Your Status
          </span>
        </motion.div>
      )
      }

      {/* Other Users' Status Bubbles */}
      {
        statusUsers
          .filter(u => u.id !== user?.id)
          .map((statusUser) => {
            const latestStatus = statusUser.statuses[0];

            return (
              <motion.button
                key={statusUser.id}
                initial={{ opacity: 0, scale: 0.8 }}
                animate={{ opacity: 1, scale: 1 }}
                onClick={() => handleStatusClick(statusUser)}
                className="flex-shrink-0 flex flex-col items-center gap-1.5 group relative"
              >
                {/* Gradient Border for Unviewed Statuses */}
                <div
                  className={cn(
                    "rounded-full p-[1.5px] w-[68px] h-[68px] flex items-center justify-center transition-all duration-300",
                    statusUser.hasUnviewed
                      ? "group-hover:shadow-md"
                      : ""
                  )}
                  style={statusUser.hasUnviewed ? {
                    background: 'conic-gradient(from 0deg, #a855f7, #ec4899, #fb923c, #a855f7)'
                  } : undefined}
                >
                  <div className="rounded-full bg-white dark:bg-gray-900 p-[2px] w-full h-full flex items-center justify-center">
                    <Avatar
                      src={statusUser.profile_picture}
                      alt={statusUser.display_name}
                      fallback={statusUser.display_name}
                      size="xl"
                      className={cn(
                        "transition-all duration-200",
                        statusUser.hasUnviewed ? "" : "opacity-90",
                        "group-hover:scale-105"
                      )}
                    />
                  </div>
                </div>

                {/* Username */}
                <span className="text-[10px] font-medium text-neutral-700 dark:text-neutral-300 truncate max-w-[64px] group-hover:text-brand-purple-600 dark:group-hover:text-brand-purple-400 transition-colors">
                  {statusUser.username}
                </span>
              </motion.button>
            );
          })
      }
    </div >
  );
}

function getTimeAgo(dateString: string): string {
  const date = new Date(dateString);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);

  if (diffMins < 1) return 'now';
  if (diffMins < 60) return `${diffMins}m`;
  if (diffHours < 24) return `${diffHours}h`;
  if (diffDays < 1) return 'today';
  return `${diffDays}d`;
}
