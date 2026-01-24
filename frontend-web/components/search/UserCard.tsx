'use client';

/**
 * UserCard Component
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Displays user in search results
 */

import { useRouter } from 'next/navigation';
import { Avatar } from '@/components/ui/Avatar';
import VerifiedBadge from '@/components/ui/VerifiedBadge';
import { MapPin, Users } from 'lucide-react';

interface UserCardProps {
  user: {
    id: string;
    username: string;
    display_name: string;
    profile_picture?: string | null;
    bio?: string | null;
    location?: string | null;
    is_verified: boolean;
    followers_count?: number;
    following_count?: number;
  };
}

export default function UserCard({ user }: UserCardProps) {
  const router = useRouter();

  const handleClick = () => {
    router.push(`/profile?u=${user.username}`);
  };

  return (
    <div
      onClick={handleClick}
      className="flex items-start gap-4 p-4 bg-white dark:bg-neutral-900 rounded-xl border border-neutral-200 dark:border-neutral-800 hover:border-brand-purple-500 hover:shadow-lg transition-all cursor-pointer"
    >
      {/* Avatar */}
      <Avatar
        src={user.profile_picture}
        alt={user.display_name}
        fallback={user.display_name}
        size="lg"
      />

      {/* User Info */}
      <div className="flex-1 min-w-0">
        {/* Name and Username */}
        <div className="flex items-center gap-2 mb-1">
          <h3 className="font-semibold text-neutral-900 dark:text-neutral-50 truncate">
            {user.display_name}
          </h3>
          {user.is_verified && <VerifiedBadge size="sm" />}
        </div>

        <p className="text-sm text-neutral-600 dark:text-neutral-400 mb-2">
          @{user.username}
        </p>

        {/* Bio */}
        {user.bio && (
          <p className="text-sm text-neutral-700 dark:text-neutral-300 mb-2 line-clamp-2">
            {user.bio}
          </p>
        )}

        {/* Meta Info */}
        <div className="flex items-center gap-4 text-xs text-neutral-500 dark:text-neutral-400">
          {user.location && (
            <div className="flex items-center gap-1">
              <MapPin className="w-3 h-3" />
              <span>{user.location}</span>
            </div>
          )}
          {user.followers_count !== undefined && (
            <div className="flex items-center gap-1">
              <Users className="w-3 h-3" />
              <span>{user.followers_count} followers</span>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

