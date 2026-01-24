'use client';

/**
 * Home Page
 * Created by: Hamza Hafeez - Founder & CEO of Histeeria
 * 
 * Main feed page with category filters and statuses
 * iOS-inspired design with glassmorphic cards
 */

import { useState } from 'react';
import { MainLayout } from '@/components/layout/MainLayout';
import { Card } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { TrendingUp, Users as UsersIcon, Plus } from 'lucide-react';
import { formatNumber } from '@/lib/utils';
import FeedContainer from '@/components/posts/FeedContainer';
import PostComposer from '@/components/posts/PostComposer';
import { Avatar } from '@/components/ui/Avatar';
import { StatusBubbles } from '@/components/statuses/StatusBubbles';
import { StatusViewer } from '@/components/statuses/StatusViewer';
import { StatusCreator } from '@/components/statuses/StatusCreator';
import { type Status } from '@/lib/api/statuses';

// Force dynamic rendering
export const dynamic = 'force-dynamic';

export default function HomePage() {
  const [activeTab, setActiveTab] = useState<'home' | 'following' | 'explore'>('home');
  const [showComposer, setShowComposer] = useState(false);
  const [showStatusCreator, setShowStatusCreator] = useState(false);
  const [selectedStatus, setSelectedStatus] = useState<{ status: Status; allStatuses: Status[] } | null>(null);

  const handleStatusClick = (status: Status, allStatuses: Status[]) => {
    setSelectedStatus({ status, allStatuses });
  };

  const handleCreateStatus = () => {
    setShowStatusCreator(true);
  };

  const handleStatusCreated = () => {
    // Trigger refresh of status bubbles
    window.dispatchEvent(new CustomEvent('status_created'));
    setShowStatusCreator(false);
  };

  return (
    <MainLayout showRightPanel={true} rightPanel={<RightPanel />}>
      <div className="space-y-4 max-w-2xl mx-auto px-4 md:px-0">
        {/* Status Bubbles */}
        <div>
          <StatusBubbles
            onStatusClick={handleStatusClick}
            onCreateClick={handleCreateStatus}
          />
        </div>

        {/* Feed Tabs */}
        <div className="flex gap-2 overflow-x-auto scrollbar-hide pb-1">
          {[
            { id: 'home' as const, label: 'For You' },
            { id: 'following' as const, label: 'Following' },
            { id: 'explore' as const, label: 'Explore' },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`px-4 py-2 rounded-full text-sm font-semibold whitespace-nowrap transition-all duration-200 flex-shrink-0 ${activeTab === tab.id
                  ? 'bg-purple-600 text-white shadow-md'
                  : 'border border-neutral-200 dark:border-neutral-800 text-neutral-700 dark:text-neutral-300 hover:border-brand-purple-500'
                }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {/* Feed Container */}
        <FeedContainer feedType={activeTab} />

        {/* Floating Create Button (Mobile) */}
        <button
          onClick={() => setShowComposer(true)}
          className="md:hidden fixed bottom-20 right-4 w-14 h-14 bg-purple-600 hover:bg-purple-700 text-white rounded-full shadow-lg flex items-center justify-center z-40"
        >
          <Plus className="w-6 h-6" />
        </button>

        {/* Post Composer Modal */}
        <PostComposer
          isOpen={showComposer}
          onClose={() => setShowComposer(false)}
          onPostCreated={() => {
            // Refresh feed after post creation
            window.location.reload();
          }}
        />

        {/* Status Creator Modal */}
        <StatusCreator
          isOpen={showStatusCreator}
          onClose={() => setShowStatusCreator(false)}
          onStatusCreated={handleStatusCreated}
        />

        {/* Status Viewer */}
        {selectedStatus && (
          <StatusViewer
            isOpen={!!selectedStatus}
            initialStatus={selectedStatus.status}
            allStatuses={selectedStatus.allStatuses}
            onClose={() => setSelectedStatus(null)}
          />
        )}
      </div>
    </MainLayout>
  );
}


function RightPanel() {
  const trendingTopics = [
    { tag: 'AI2025', posts: 12500 },
    { tag: 'WebDevelopment', posts: 8900 },
    { tag: 'Blockchain', posts: 6700 },
    { tag: 'Startups', posts: 5400 },
  ];

  const suggestedCommunities = [
    { name: 'Tech Hub', members: 24000, avatar: null },
    { name: 'Designers United', members: 8500, avatar: null },
    { name: 'Startup Founders', members: 12000, avatar: null },
  ];

  return (
    <div className="space-y-6">
      {/* Trending Topics */}
      <Card variant="solid" hoverable={false}>
        <div className="flex items-center gap-2 mb-4">
          <TrendingUp className="w-5 h-5 text-brand-purple-600" />
          <h3 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50">
            Trending Topics
          </h3>
        </div>
        <div className="space-y-3">
          {trendingTopics.map((topic, index) => (
            <button
              key={topic.tag}
              className="w-full text-left p-3 rounded-lg hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors"
            >
              <div className="flex items-start justify-between">
                <div>
                  <p className="text-xs text-neutral-500 dark:text-neutral-400">
                    #{index + 1} Trending
                  </p>
                  <p className="text-sm font-semibold text-neutral-900 dark:text-neutral-50">
                    #{topic.tag}
                  </p>
                  <p className="text-xs text-neutral-500 dark:text-neutral-400">
                    {formatNumber(topic.posts)} posts
                  </p>
                </div>
              </div>
            </button>
          ))}
        </div>
      </Card>

      {/* Suggested Communities */}
      <Card variant="solid" hoverable={false}>
        <div className="flex items-center gap-2 mb-4">
          <UsersIcon className="w-5 h-5 text-brand-purple-600" />
          <h3 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50">
            Suggested Communities
          </h3>
        </div>
        <div className="space-y-3">
          {suggestedCommunities.map((community) => (
            <div
              key={community.name}
              className="flex items-center gap-3 p-3 rounded-lg hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors"
            >
              <Avatar
                src={community.avatar}
                alt={community.name}
                fallback={community.name}
                size="md"
              />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-neutral-900 dark:text-neutral-50 truncate">
                  {community.name}
                </p>
                <p className="text-xs text-neutral-500 dark:text-neutral-400">
                  {formatNumber(community.members)} members
                </p>
              </div>
              <Button variant="secondary" size="sm">
                Join
              </Button>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}

