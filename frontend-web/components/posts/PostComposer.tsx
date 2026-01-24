'use client';

import { useState } from 'react';
import { X, FileText, BarChart3, Newspaper } from 'lucide-react';
import TextPostComposer from './TextPostComposer';
import PollComposer from './PollComposer';
import ArticleComposer from './ArticleComposer';

interface PostComposerProps {
  isOpen: boolean;
  onClose: () => void;
  initialType?: 'post' | 'poll' | 'article';
  onPostCreated?: (post: any) => void;
}

type TabType = 'post' | 'poll' | 'article';

export default function PostComposer({ 
  isOpen, 
  onClose, 
  initialType = 'post',
  onPostCreated 
}: PostComposerProps) {
  const [activeTab, setActiveTab] = useState<TabType>(initialType);

  if (!isOpen) return null;

  const tabs = [
    { id: 'post' as TabType, label: 'Post', icon: FileText, description: 'Share a quick update' },
    { id: 'poll' as TabType, label: 'Poll', icon: BarChart3, description: 'Ask a question' },
    { id: 'article' as TabType, label: 'Article', icon: Newspaper, description: 'Write long-form content' },
  ];

  return (
    <div className="fixed inset-0 z-40 md:z-50 flex items-center justify-center md:bg-black/50 md:backdrop-blur-sm animate-fade-in">
      {/* Mobile: fit between header and footer; Desktop: centered modal */}
      <div className="relative w-full h-[calc(100vh-112px)] top-14 md:top-auto bottom-14 md:bottom-auto md:h-auto md:max-w-3xl md:max-h-[90vh] bg-white dark:bg-neutral-900 rounded-none md:rounded-2xl shadow-2xl flex flex-col animate-scale-in">
        {/* Header */}
        <div className="flex items-center justify-between px-4 md:px-6 py-3 md:py-4 border-b border-neutral-200 dark:border-neutral-800">
          <h2 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50">
            Create Content
          </h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-neutral-100 dark:hover:bg-neutral-800 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-neutral-600 dark:text-neutral-400" />
          </button>
        </div>

        {/* Tabs */}
        <div className="flex gap-2 px-3 md:px-6 py-2.5 md:py-4 border-b border-neutral-200 dark:border-neutral-800 overflow-x-auto">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`flex items-center gap-2 px-3 md:px-4 py-2 rounded-lg transition-all whitespace-nowrap ${
                  isActive
                    ? 'bg-purple-600 text-white shadow-md'
                    : 'bg-neutral-100 dark:bg-neutral-800 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-200 dark:hover:bg-neutral-700'
                }`}
              >
                <Icon className="w-4 h-4" />
                <div className="text-left">
                  <div className="text-sm font-semibold">{tab.label}</div>
                  {!isActive && (
                    <div className="hidden md:block text-xs opacity-70">{tab.description}</div>
                  )}
                </div>
              </button>
            );
          })}
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto">
          {activeTab === 'post' && <TextPostComposer onClose={onClose} onPostCreated={onPostCreated} />}
          {activeTab === 'poll' && <PollComposer onClose={onClose} onPostCreated={onPostCreated} />}
          {activeTab === 'article' && <ArticleComposer onClose={onClose} onPostCreated={onPostCreated} />}
        </div>
      </div>
    </div>
  );
}

