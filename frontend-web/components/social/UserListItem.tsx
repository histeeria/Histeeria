'use client';

/**
 * User List Item Component
 * Displays a user in followers/following/connections lists
 */

import Link from 'next/link';
import { Avatar } from '@/components/ui/Avatar';
import VerifiedBadge from '@/components/ui/VerifiedBadge';
import { Button } from '@/components/ui/Button';
import RelationshipButton from './RelationshipButton';

interface UserListItemProps {
  user: {
    id: string;
    username: string;
    display_name: string;
    profile_picture?: string;
    is_verified: boolean;
    bio?: string;
    followers_count?: number;
  };
  showRelationshipButton?: boolean;
  isOwnProfile?: boolean;
}

export default function UserListItem({ user, showRelationshipButton = true, isOwnProfile = false }: UserListItemProps) {
  return (
    <div className="flex items-center gap-4 p-4 hover:bg-neutral-50 dark:hover:bg-neutral-800/50 transition-colors">
      {/* Avatar */}
      <Link href={`/profile?u=${user.username}`}>
        <Avatar
          src={user.profile_picture}
          alt={user.display_name}
          fallback={user.display_name}
          size="lg"
          className="cursor-pointer"
        />
      </Link>

      {/* User Info */}
      <div className="flex-1 min-w-0">
        <Link href={`/profile?u=${user.username}`} className="hover:underline">
          <div className="flex items-center gap-2">
            <h3 className="font-semibold text-neutral-900 dark:text-neutral-50 truncate">
              {user.display_name}
            </h3>
            {user.is_verified && <VerifiedBadge size="sm" />}
          </div>
        </Link>
        
        <p className="text-sm text-neutral-600 dark:text-neutral-400">
          @{user.username}
        </p>

        {user.bio && (
          <p className="text-sm text-neutral-600 dark:text-neutral-400 mt-1 line-clamp-2">
            {user.bio}
          </p>
        )}

        {user.followers_count !== undefined && (
          <p className="text-xs text-neutral-500 dark:text-neutral-500 mt-1">
            {user.followers_count} {user.followers_count === 1 ? 'follower' : 'followers'}
          </p>
        )}
      </div>

      {/* Relationship Button */}
      {showRelationshipButton && !isOwnProfile && (
        <div className="flex-shrink-0">
          <RelationshipButton targetUserId={user.id} />
        </div>
      )}
    </div>
  );
}

