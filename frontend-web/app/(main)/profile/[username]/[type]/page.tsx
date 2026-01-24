'use client';

/**
 * Profile Relationships List Page
 * Displays followers, following, connections, or collaborators
 * Instagram-style full page list
 */

import { useState, useEffect, useRef } from 'react';
import { useParams, useRouter, useSearchParams } from 'next/navigation';
import { MainLayout } from '@/components/layout/MainLayout';
import { Card } from '@/components/ui/Card';
import { ArrowLeft, Users } from 'lucide-react';
import { relationshipAPI } from '@/lib/api';
import UserListItem from '@/components/social/UserListItem';

type ListType = 'followers' | 'following' | 'connections' | 'collaborators';

interface User {
  id: string;
  username: string;
  display_name: string;
  profile_picture?: string;
  is_verified: boolean;
  bio?: string;
  followers_count?: number;
}

export default function RelationshipsListPage() {
  const params = useParams();
  const router = useRouter();
  const searchParams = useSearchParams();
  const username = params.username as string;
  const type = params.type as ListType;
  const userId = searchParams.get('userId'); // Get userId from query params
  
  const handleBack = () => {
    router.push(`/profile?u=${username}`);
  };

  const [users, setUsers] = useState<User[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [hasMore, setHasMore] = useState(true);
  const [page, setPage] = useState(1);
  const scrollRef = useRef<HTMLDivElement>(null);

  const titles: Record<ListType, string> = {
    followers: 'Followers',
    following: 'Following',
    connections: 'Connections',
    collaborators: 'Collaborators',
  };

  const fetchUsers = async (pageNum: number) => {
    setIsLoading(true);

    try {
      let response;
      
      switch (type) {
        case 'followers':
          response = await relationshipAPI.getFollowers(userId || undefined, pageNum, 20);
          break;
        case 'following':
          response = await relationshipAPI.getFollowing(userId || undefined, pageNum, 20);
          break;
        case 'connections':
          response = await relationshipAPI.getConnections(userId || undefined, pageNum, 20);
          break;
        case 'collaborators':
          response = await relationshipAPI.getCollaborators(userId || undefined, pageNum, 20);
          break;
        default:
          return;
      }

      if (response.success && response.users) {
        if (pageNum === 1) {
          setUsers(response.users);
        } else {
          setUsers(prev => [...prev, ...response.users]);
        }
        setHasMore(response.users.length >= 20);
      }
    } catch (error) {
      console.error('Failed to fetch users:', error);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    setPage(1);
    fetchUsers(1);
  }, [type, userId]);

  // Infinite scroll
  useEffect(() => {
    const scrollContainer = scrollRef.current;
    if (!scrollContainer) return;

    const handleScroll = () => {
      const { scrollTop, scrollHeight, clientHeight } = scrollContainer;
      if (scrollHeight - scrollTop <= clientHeight * 1.5 && !isLoading && hasMore) {
        const nextPage = page + 1;
        setPage(nextPage);
        fetchUsers(nextPage);
      }
    };

    scrollContainer.addEventListener('scroll', handleScroll);
    return () => scrollContainer.removeEventListener('scroll', handleScroll);
  }, [isLoading, hasMore, page]);

  return (
    <MainLayout>
      <div className="max-w-2xl mx-auto">
        {/* Header */}
        <div className="flex items-center gap-4 mb-6">
          <button
            onClick={handleBack}
            className="p-2 hover:bg-neutral-100 dark:hover:bg-neutral-800 rounded-lg transition-colors"
          >
            <ArrowLeft className="w-5 h-5 text-neutral-700 dark:text-neutral-300" />
          </button>
          
          <div>
            <h1 className="text-2xl font-bold text-neutral-900 dark:text-neutral-50">
              {titles[type] || 'Users'}
            </h1>
            <p className="text-sm text-neutral-500 dark:text-neutral-400">
              @{username}
            </p>
          </div>
        </div>

        {/* Users List */}
        <Card variant="solid" hoverable={false}>
          {isLoading && users.length === 0 ? (
            <div className="py-16 text-center">
              <div className="inline-block w-10 h-10 border-3 border-brand-purple-600 border-t-transparent rounded-full animate-spin mb-4" />
              <p className="text-sm font-medium text-neutral-600 dark:text-neutral-400">
                Loading {type}...
              </p>
            </div>
          ) : users.length === 0 ? (
            <div className="py-16 text-center">
              <div className="inline-flex items-center justify-center w-20 h-20 bg-neutral-100 dark:bg-neutral-800 rounded-full mb-4">
                <Users className="w-10 h-10 text-neutral-400 dark:text-neutral-600" />
              </div>
              <p className="text-lg font-semibold text-neutral-900 dark:text-neutral-50 mb-1">
                No {type} yet
              </p>
              <p className="text-sm text-neutral-500 dark:text-neutral-400">
                {type === 'followers' && 'No one is following this user yet'}
                {type === 'following' && 'Not following anyone yet'}
                {type === 'connections' && 'No connections yet'}
                {type === 'collaborators' && 'No collaborators yet'}
              </p>
            </div>
          ) : (
            <div
              ref={scrollRef}
              className="divide-y divide-neutral-100 dark:divide-neutral-800 max-h-[calc(100vh-200px)] overflow-y-auto"
              style={{ scrollbarWidth: 'thin' }}
            >
              {users.map((user) => (
                <UserListItem
                  key={user.id}
                  user={user}
                  showRelationshipButton={true}
                />
              ))}
              
              {isLoading && (
                <div className="py-6 text-center">
                  <div className="inline-block w-6 h-6 border-2 border-brand-purple-600 border-t-transparent rounded-full animate-spin" />
                </div>
              )}
            </div>
          )}
        </Card>
      </div>
    </MainLayout>
  );
}

