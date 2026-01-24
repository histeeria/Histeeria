'use client';

/**
 * Universal Create Experience
 * Designed by: Hamza Hafeez - Founder & CEO of Upvista
 * Philosophy: Clarity over complexity
 */

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { MainLayout } from '@/components/layout/MainLayout';
import { 
  FileText, 
  BarChart3, 
  Newspaper, 
  Video,
  ArrowRight,
  Sparkles,
  Clock
} from 'lucide-react';
import PostComposer from '@/components/posts/PostComposer';
import { motion, AnimatePresence } from 'framer-motion';
import { toast } from '@/components/ui/Toast';

type ContentType = 'post' | 'poll' | 'article' | 'reel';

interface ContentOption {
  id: ContentType;
  icon: any;
  emoji: string;
  label: string;
  description: string;
  tagline: string;
  available: boolean;
  color: 'blue' | 'green' | 'orange' | 'pink';
}

export default function CreatePage() {
  const router = useRouter();
  const [selectedType, setSelectedType] = useState<ContentType | null>(null);
  const [hoveredId, setHoveredId] = useState<ContentType | null>(null);

  const contentOptions: ContentOption[] = [
    {
      id: 'post',
      icon: FileText,
      emoji: '',
      label: 'Post',
      description: 'Share your thoughts with the world',
      tagline: 'Quick updates, big impact',
      available: true,
      color: 'blue',
    },
    {
      id: 'poll',
      icon: BarChart3,
      emoji: '',
      label: 'Poll',
      description: 'Ask your audience a question',
      tagline: 'Engage and gather insights',
      available: true,
      color: 'green',
    },
    {
      id: 'article',
      icon: Newspaper,
      emoji: '',
      label: 'Article',
      description: 'Write something meaningful',
      tagline: 'Long-form, rich content',
      available: true,
      color: 'orange',
    },
    {
      id: 'reel',
      icon: Video,
      emoji: '',
      label: 'Reel',
      description: 'Share a short video',
      tagline: 'Coming soon',
      available: false,
      color: 'pink',
    },
  ];

  const handleSelect = (type: ContentType, available: boolean) => {
    if (!available) {
      toast.info('Reels coming soon! 🎬 We\'re working on something amazing');
      return;
    }
    setSelectedType(type);
  };

  const handleClose = () => {
    if (selectedType) {
      setSelectedType(null);
    } else {
      router.back();
    }
  };

  const handlePostCreated = () => {
    setSelectedType(null);
    router.push('/home');
  };

  // Show composer if type selected
  if (selectedType && selectedType !== 'reel') {
    return (
      <MainLayout>
        <PostComposer 
          isOpen={true}
          initialType={selectedType}
          onClose={handleClose}
          onPostCreated={handlePostCreated}
        />
      </MainLayout>
    );
  }

  return (
    <MainLayout>
      <div className="min-h-screen flex items-start md:items-center justify-center px-4 py-4 md:py-12">
        <div className="w-full max-w-3xl">
          {/* Hero Section */}
          <motion.div 
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            className="text-center mb-6 md:mb-12"
          >
            <motion.div
              animate={{ 
                scale: [1, 1.05, 1],
              }}
              transition={{ 
                duration: 2,
                repeat: Infinity,
                repeatType: "reverse"
              }}
              className="inline-block mb-4"
            >
              <Sparkles className="w-12 h-12 text-purple-500" />
            </motion.div>
            <h1 className="text-2xl md:text-5xl font-bold text-black dark:text-white mb-2 md:mb-3">
              What would you like to create?
            </h1>
            <p className="text-sm md:text-lg text-neutral-700 dark:text-neutral-300">
              Choose a format and start sharing
            </p>
          </motion.div>

          {/* Options List */}
          <div className="space-y-2 md:space-y-3">
            {contentOptions.map((option, index) => {
              const Icon = option.icon;
              const isHovered = hoveredId === option.id;
              
              // Get color classes based on color prop
              const getColorClasses = (color: string) => {
                switch(color) {
                  case 'blue':
                    return {
                      bg: 'bg-blue-500',
                      bgHover: 'hover:bg-blue-600',
                      bgLight: 'bg-blue-50 dark:bg-blue-950/30',
                      border: 'border-blue-200 dark:border-blue-800',
                      borderHover: 'hover:border-blue-400 dark:hover:border-blue-500',
                      text: 'text-blue-600 dark:text-blue-400',
                      shadow: 'hover:shadow-blue-500/20',
                      gradient: 'from-blue-50/50 to-blue-100/50 dark:from-blue-950/20 dark:to-blue-900/20',
                    };
                  case 'green':
                    return {
                      bg: 'bg-green-500',
                      bgHover: 'hover:bg-green-600',
                      bgLight: 'bg-green-50 dark:bg-green-950/30',
                      border: 'border-green-200 dark:border-green-800',
                      borderHover: 'hover:border-green-400 dark:hover:border-green-500',
                      text: 'text-green-600 dark:text-green-400',
                      shadow: 'hover:shadow-green-500/20',
                      gradient: 'from-green-50/50 to-green-100/50 dark:from-green-950/20 dark:to-green-900/20',
                    };
                  case 'orange':
                    return {
                      bg: 'bg-orange-500',
                      bgHover: 'hover:bg-orange-600',
                      bgLight: 'bg-orange-50 dark:bg-orange-950/30',
                      border: 'border-orange-200 dark:border-orange-800',
                      borderHover: 'hover:border-orange-400 dark:hover:border-orange-500',
                      text: 'text-orange-600 dark:text-orange-400',
                      shadow: 'hover:shadow-orange-500/20',
                      gradient: 'from-orange-50/50 to-orange-100/50 dark:from-orange-950/20 dark:to-orange-900/20',
                    };
                  case 'pink':
                    return {
                      bg: 'bg-pink-500',
                      bgHover: 'hover:bg-pink-600',
                      bgLight: 'bg-pink-50 dark:bg-pink-950/30',
                      border: 'border-pink-200 dark:border-pink-800',
                      borderHover: 'hover:border-pink-400 dark:hover:border-pink-500',
                      text: 'text-pink-600 dark:text-pink-400',
                      shadow: 'hover:shadow-pink-500/20',
                      gradient: 'from-pink-50/50 to-pink-100/50 dark:from-pink-950/20 dark:to-pink-900/20',
                    };
                  default:
                    return {
                      bg: 'bg-neutral-500',
                      bgHover: 'hover:bg-neutral-600',
                      bgLight: 'bg-neutral-50 dark:bg-neutral-800',
                      border: 'border-neutral-200 dark:border-neutral-700',
                      borderHover: 'hover:border-neutral-400',
                      text: 'text-neutral-600 dark:text-neutral-400',
                      shadow: 'hover:shadow-neutral-500/20',
                      gradient: 'from-neutral-50 to-neutral-100 dark:from-neutral-900 dark:to-neutral-800',
                    };
                }
              };
              
              const colors = getColorClasses(option.color);
              
              return (
                <motion.button
                  key={option.id}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: index * 0.1 }}
                  onClick={() => handleSelect(option.id, option.available)}
                  onMouseEnter={() => setHoveredId(option.id)}
                  onMouseLeave={() => setHoveredId(null)}
                  disabled={!option.available}
                  className={`
                    w-full group relative overflow-hidden
                    bg-white/60 dark:bg-neutral-800/40 backdrop-blur-[4px]
                    border transition-all duration-300
                    rounded-xl md:rounded-2xl p-4 md:p-6
                    ${option.available 
                      ? `${colors.border} ${colors.borderHover} hover:shadow-md md:hover:shadow-xl ${colors.shadow} cursor-pointer active:scale-[0.99]` 
                      : 'border-neutral-100 dark:border-neutral-800/70 opacity-60 cursor-not-allowed'
                    }
                  `}
                >
                  {/* Background Gradient on Hover */}
                  <AnimatePresence>
                    {isHovered && option.available && (
                      <motion.div
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        className={`absolute inset-0 bg-gradient-to-r ${colors.gradient}`}
                      />
                    )}
                  </AnimatePresence>

                  {/* Content */}
                  <div className="relative flex items-center justify-between gap-6">
                    {/* Left: Icon + Text */}
                    <div className="flex items-center gap-4 md:gap-5 flex-1">
                      {/* Colored Icon Container */}
                      <div className={`
                        w-12 h-12 md:w-16 md:h-16 
                        rounded-xl md:rounded-2xl 
                        flex items-center justify-center
                        transition-all duration-300
                        ${option.available 
                          ? `${colors.bgLight} ${colors.bg} ${colors.bgHover} group-hover:scale-110 group-hover:rotate-3 shadow-lg` 
                          : 'bg-neutral-100 dark:bg-neutral-800'
                        }
                      `}>
                        <Icon className={`
                          w-6 h-6 md:w-8 md:h-8 
                          transition-colors duration-300
                          ${option.available 
                            ? 'text-white' 
                            : 'text-neutral-400 dark:text-neutral-600'
                          }
                        `} />
                      </div>

                      {/* Text */}
                        <div className="flex-1 text-left">
                          <div className="flex items-center gap-3 mb-1">
                            <h3 className="text-lg md:text-2xl font-bold text-black dark:text-white">
                              {option.label}
                            </h3>
                          {!option.available && (
                            <span className="px-2.5 py-0.5 bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-300 rounded-full text-xs font-semibold">
                              Coming Soon
                            </span>
                          )}
                        </div>
                          <p className="text-xs md:text-base text-neutral-700 dark:text-neutral-300 mb-1">
                            {option.description}
                          </p>
                        <p className={`text-xs md:text-sm font-semibold ${colors.text}`}>
                          {option.tagline}
                        </p>
                      </div>
                    </div>

                    {/* Right: Arrow Button */}
                    {option.available && (
                      <motion.div
                        animate={{ 
                          x: isHovered ? 5 : 0,
                        }}
                        transition={{ duration: 0.2 }}
                        className="flex-shrink-0"
                      >
                        <div className={`
                          w-10 h-10 md:w-12 md:h-12 rounded-lg md:rounded-xl
                          flex items-center justify-center
                          transition-all duration-300
                          ${isHovered 
                            ? `${colors.bg} text-white shadow-lg ${colors.shadow}` 
                            : 'bg-neutral-100 dark:bg-neutral-700 text-neutral-600 dark:text-neutral-400'
                          }
                        `}>
                          <ArrowRight className="w-5 h-5" />
                        </div>
                      </motion.div>
                    )}
                  </div>

                  {/* Shimmer Effect on Hover */}
                  {option.available && isHovered && (
                    <motion.div
                      initial={{ x: '-100%' }}
                      animate={{ x: '100%' }}
                      transition={{ 
                        duration: 0.8,
                        ease: "easeInOut",
                        repeat: Infinity,
                        repeatDelay: 0.3
                      }}
                      className="absolute inset-0 bg-gradient-to-r from-transparent via-white/30 dark:via-white/10 to-transparent"
                      style={{ width: '30%' }}
                    />
                  )}
                </motion.button>
              );
            })}
          </div>

          {/* Bottom Hint */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.6 }}
            className="mt-12 text-center"
          >
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-neutral-100/50 dark:bg-neutral-800/30 backdrop-blur-sm rounded-full text-sm text-neutral-600 dark:text-neutral-400">
              <Clock className="w-3.5 h-3.5" />
              <span>Tip: All posts auto-save as drafts</span>
            </div>
          </motion.div>
        </div>
      </div>
    </MainLayout>
  );
}

