'use client';

/**
 * Activity Main Page
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Main activity menu with error boundary
 */

import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { motion } from 'framer-motion';
import { ErrorBoundary } from '@/components/errors/ErrorBoundary';
import { MainLayout } from '@/components/layout/MainLayout';
import { 
  Heart, 
  MessageCircle, 
  Repeat2, 
  Tag, 
  Smile, 
  Star,
  Trash2, 
  Archive,
  Grid3x3,
  Video,
  ChevronRight,
  Share2,
  Lightbulb,
  DollarSign,
  Clock,
  History,
  Search,
  Link2,
  Briefcase,
  Building2,
  CreditCard,
  X,
  Newspaper,
} from 'lucide-react';

interface ActivityItem {
  id: string;
  label: string;
  icon: typeof Heart;
  href?: string;
  onClick?: () => void;
}

interface ActivitySection {
  title: string;
  items: ActivityItem[];
}

function ActivityPageContent() {
  const router = useRouter();

  // Force black background
  useEffect(() => {
    const layoutWrapper = document.querySelector('[class*="bg-neutral-50"], [class*="bg-neutral-950"]');
    if (layoutWrapper) {
      (layoutWrapper as HTMLElement).style.backgroundColor = '#000000';
    }
    document.body.style.backgroundColor = '#000000';
    
    return () => {
      document.body.style.backgroundColor = '';
      if (layoutWrapper) {
        (layoutWrapper as HTMLElement).style.backgroundColor = '';
      }
    };
  }, []);

  const sections: ActivitySection[] = [
    {
      title: 'Interactions',
      items: [
        {
          id: 'likes',
          label: 'Likes',
          icon: Heart,
          href: '/activity/interactions?filter=likes',
        },
        {
          id: 'comments',
          label: 'Comments',
          icon: MessageCircle,
          href: '/activity/interactions?filter=comments',
        },
        {
          id: 'reposts',
          label: 'Reposts',
          icon: Repeat2,
          href: '/activity/interactions?filter=reposts',
        },
        {
          id: 'tags',
          label: 'Tags',
          icon: Tag,
          href: '/activity/interactions?filter=tags',
        },
        {
          id: 'sticker-responses',
          label: 'Sticker responses',
          icon: Smile,
          href: '/activity/interactions?filter=sticker-responses',
        },
        {
          id: 'reviews',
          label: 'Reviews',
          icon: Star,
          href: '/activity/interactions?filter=reviews',
        },
      ],
    },
    {
      title: 'Removed and archived content',
      items: [
        {
          id: 'recently-deleted',
          label: 'Recently deleted',
          icon: Trash2,
          href: '/activity/archived?filter=deleted',
        },
        {
          id: 'archived',
          label: 'Archived',
          icon: Archive,
          href: '/activity/archived?filter=archived',
        },
      ],
    },
    {
      title: 'Content you shared',
      items: [
        {
          id: 'posts',
          label: 'Posts',
          icon: Grid3x3,
          href: '/activity/shared?filter=posts',
        },
        {
          id: 'articles',
          label: 'Articles',
          icon: Newspaper,
          href: '/activity/shared?filter=articles',
        },
        {
          id: 'reels',
          label: 'Reels',
          icon: Video,
          href: '/activity/shared?filter=reels',
        },
        {
          id: 'projects',
          label: 'Projects',
          icon: Briefcase,
          href: '/activity/shared?filter=projects',
        },
        {
          id: 'jobs',
          label: 'Jobs',
          icon: Building2,
          href: '/activity/shared?filter=jobs',
        },
      ],
    },
    {
      title: 'Suggested content',
      items: [
        {
          id: 'not-interested',
          label: 'Not interested',
          icon: X,
          href: '/activity/suggested?filter=not-interested',
        },
        {
          id: 'interested',
          label: 'Interested',
          icon: Lightbulb,
          href: '/activity/suggested?filter=interested',
        },
      ],
    },
    {
      title: 'Your finances',
      items: [
        {
          id: 'projects',
          label: 'Your Projects',
          icon: Briefcase,
          href: '/activity/finances?filter=projects',
        },
        {
          id: 'jobs',
          label: 'Your Jobs',
          icon: Building2,
          href: '/activity/finances?filter=jobs',
        },
        {
          id: 'earnings',
          label: 'Your Earnings',
          icon: DollarSign,
          href: '/activity/finances?filter=earnings',
        },
        {
          id: 'spendings',
          label: 'Your Spendings',
          icon: CreditCard,
          href: '/activity/finances?filter=spendings',
        },
        {
          id: 'reviews',
          label: 'Your Reviews',
          icon: Star,
          href: '/activity/finances?filter=reviews',
        },
      ],
    },
    {
      title: 'How you use this app',
      items: [
        {
          id: 'time',
          label: 'Time spent',
          icon: Clock,
          href: '/activity/usage?filter=time',
        },
        {
          id: 'watch',
          label: 'Watch history',
          icon: History,
          href: '/activity/usage?filter=watch',
        },
        {
          id: 'account',
          label: 'Account history',
          icon: History,
          href: '/activity/usage?filter=account',
        },
        {
          id: 'searches',
          label: 'Recent searches',
          icon: Search,
          href: '/activity/usage?filter=searches',
        },
        {
          id: 'links',
          label: 'Link history',
          icon: Link2,
          href: '/activity/usage?filter=links',
        },
        {
          id: 'jobs',
          label: 'Recent jobs',
          icon: Briefcase,
          href: '/activity/usage?filter=jobs',
        },
        {
          id: 'earnings',
          label: 'Recent earnings',
          icon: DollarSign,
          href: '/activity/usage?filter=earnings',
        },
      ],
    },
  ];

  const handleItemClick = (item: ActivityItem) => {
    if (item.onClick) {
      item.onClick();
    } else if (item.href) {
      router.push(item.href);
    }
  };

  return (
    <MainLayout>
      <div className="absolute bg-black lg:left-60 md:inset-0" style={{ top: '56px', bottom: '56px', left: 0, right: 0, zIndex: 1 }}>
        <div className="relative min-h-full bg-black w-full h-full overflow-y-auto">
          {/* Mobile Header - Instagram Style (replaces Topbar content) */}
          <div className="md:hidden sticky top-0 z-10 bg-black border-b border-neutral-800">
            <div className="flex items-center px-4 py-3">
              <button
                onClick={() => router.back()}
                className="p-2 -ml-2 hover:bg-neutral-900 rounded-full transition-colors"
              >
                <svg
                  className="w-6 h-6 text-neutral-50"
                  fill="none"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="2"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path d="M15 18l-6-6 6-6" />
                </svg>
              </button>
              <h1 className="flex-1 text-center text-base font-semibold text-neutral-50">
                Your activity
              </h1>
              <div className="w-10" /> {/* Spacer for centering */}
            </div>
          </div>

          {/* Desktop Header */}
          <div className="hidden md:block sticky top-0 z-10 bg-black/80 backdrop-blur-xl border-b border-neutral-800">
            <div className="flex items-center px-6 py-4 max-w-4xl mx-auto">
              <button
                onClick={() => router.back()}
                className="p-2 -ml-2 hover:bg-neutral-900 rounded-full transition-colors"
              >
                <svg
                  className="w-6 h-6 text-neutral-50"
                  fill="none"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="2"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path d="M15 18l-6-6 6-6" />
                </svg>
              </button>
              <h1 className="flex-1 text-center text-lg font-semibold text-neutral-50">
                Your activity
              </h1>
              <div className="w-10" /> {/* Spacer for centering */}
            </div>
          </div>

          {/* Content */}
          <div className="max-w-4xl mx-auto px-4 py-4 md:py-6 pb-20 md:pb-6">
            {sections.map((section, sectionIndex) => (
              <motion.div
                key={section.title}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: sectionIndex * 0.05 }}
                className="mb-0"
              >
                {/* Super Divider - Between Sections (Bold) */}
                {sectionIndex > 0 && (
                  <div className="h-[2px] bg-neutral-800 mb-6 md:mb-8" />
                )}

                {/* Section Title */}
                <h2 className="text-xs font-semibold text-neutral-500 uppercase tracking-wider mb-3 px-4">
                  {section.title}
                </h2>

                {/* Section Items - No borders, just dividers */}
                <div className="bg-black rounded-lg overflow-hidden">
                  {section.items.map((item, itemIndex) => {
                    const Icon = item.icon;
                    const isLast = itemIndex === section.items.length - 1;

                    return (
                      <div key={item.id}>
                        <motion.button
                          whileTap={{ scale: 0.98 }}
                          onClick={() => handleItemClick(item)}
                          className="
                            w-full flex items-center justify-between px-4 py-3.5
                            transition-colors duration-150
                            hover:bg-neutral-900
                            active:bg-neutral-800
                          "
                        >
                          <div className="flex items-center gap-3 flex-1 min-w-0">
                            <Icon className="w-6 h-6 text-neutral-50 flex-shrink-0" />
                            <span className="text-sm font-normal text-neutral-50">
                              {item.label}
                            </span>
                          </div>
                          <ChevronRight className="w-5 h-5 text-neutral-600 flex-shrink-0" />
                        </motion.button>
                        {/* Sub Divider - Between Items (Desktop Only) */}
                        {!isLast && (
                          <div className="hidden md:block h-px bg-neutral-800 mx-4" />
                        )}
                      </div>
                    );
                  })}
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </MainLayout>
  );
}

export default function ActivityPage() {
  return (
    <ErrorBoundary>
      <ActivityPageContent />
    </ErrorBoundary>
  );
}
