'use client';

import { useRouter } from 'next/navigation';
import { Post } from '@/lib/api/posts';
import { Avatar } from '../ui/Avatar';
import { Badge } from '../ui/Badge';
import { formatPostTimestamp } from '@/lib/api/posts';
import { Clock, BookOpen, Share2 } from 'lucide-react';
import VerifiedBadge from '../ui/VerifiedBadge';
import PostActions from './PostActions';
import CommentModal from './CommentModal';
import TableOfContents from './TableOfContents';
import ReadingProgress from './ReadingProgress';
import { useState, useEffect, useMemo } from 'react';

interface ArticleViewProps {
  post: Post;
  onComment?: (post: Post) => void;
  onShare?: (post: Post) => void;
  onSave?: (post: Post) => void;
  onClose?: () => void;
}

export default function ArticleView({ 
  post, 
  onComment,
  onShare,
  onSave,
  onClose
}: ArticleViewProps) {
  const router = useRouter();
  const [showCommentModal, setShowCommentModal] = useState(false);
  
  // Produce HTML with stable heading IDs so TOC anchors work reliably
  const processedHtml = useMemo(() => {
    if (!post.article?.content_html) return '';
    if (typeof window === 'undefined') return post.article.content_html;
    try {
      const tempDiv = document.createElement('div');
      tempDiv.innerHTML = post.article.content_html;
      const headings = tempDiv.querySelectorAll('h1, h2, h3, h4, h5, h6');
      const seen = new Set<string>();
      headings.forEach((heading) => {
        const base = (heading.textContent || '')
          .toLowerCase()
          .trim()
          .replace(/\s+/g, '-')
          .replace(/[^a-z0-9-]/g, '');
        let candidate = base || 'section';
        let suffix = 1;
        while (seen.has(candidate)) {
          suffix += 1;
          candidate = `${base}-${suffix}`;
        }
        heading.id = candidate;
        seen.add(candidate);
      });
      return tempDiv.innerHTML;
    } catch {
      return post.article.content_html;
    }
  }, [post.article?.content_html]);
  
  if (!post.article) {
    return null;
  }

  const article = post.article;
  
  const handleShare = () => {
    if (navigator.share) {
      navigator.share({
        title: article.title,
        text: article.subtitle || '',
        url: window.location.href,
      }).catch(() => {
        // Fallback to copy
        copyToClipboard();
      });
    } else {
      copyToClipboard();
    }
    onShare?.(post);
  };
  
  const copyToClipboard = () => {
    navigator.clipboard.writeText(window.location.href);
    // You might want to show a toast here
  };

  const handleProfileClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (post.author?.username) {
      router.push(`/profile?u=${post.author.username}`);
    }
  };

  return (
    <div className="w-full h-full flex flex-col bg-white dark:bg-gray-900 relative">
      {/* Reading Progress Bar */}
      <ReadingProgress />
      
      {/* Cover Image - Full Width Hero */}
      {article.cover_image_url && (
        <div className="w-full h-80 md:h-[32rem] relative overflow-hidden">
          <img
            src={article.cover_image_url}
            alt={article.title}
            className="w-full h-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black/40 via-black/10 to-transparent" />
        </div>
      )}

      {/* Scrollable Content Container */}
      <div className="flex-1 overflow-y-auto">
        {/* Article Container - Centered with Max Width and TOC */}
        <div className="max-w-7xl mx-auto px-4 md:px-8 lg:px-12 py-8 md:py-12">
          <div className="flex gap-8">
            {/* Main Content */}
            <div className="flex-1 max-w-4xl">
          {/* Author Header */}
          <div className="flex items-center gap-4 mb-8 pb-6 pt-2 border-b border-neutral-200 dark:border-neutral-800">
            <button
              onClick={handleProfileClick}
              className="flex-shrink-0 cursor-pointer hover:opacity-80 transition-opacity"
            >
              <Avatar 
                src={post.author?.profile_picture} 
                alt={post.author?.display_name || post.author?.username || 'User'} 
                fallback={post.author?.display_name || post.author?.username || 'U'}
                size="lg"
              />
            </button>
            <div className="flex-1 min-w-0">
              <button
                onClick={handleProfileClick}
                className="flex items-center gap-1.5 hover:opacity-80 transition-opacity w-full mb-1"
              >
                <h3 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50 truncate">
                  {post.author?.display_name || post.author?.username}
                </h3>
                {post.author?.is_verified && (
                  <>
                    <span className="text-sm text-neutral-400 dark:text-neutral-600">·</span>
                    <VerifiedBadge size="sm" variant="badge" showText={false} />
                  </>
                )}
                <span className="text-sm text-neutral-400 dark:text-neutral-600">·</span>
                <span className="text-sm text-neutral-500 dark:text-neutral-400 whitespace-nowrap">
                  {formatPostTimestamp(post.created_at)}
                </span>
              </button>
              <button
                onClick={handleProfileClick}
                className="text-sm text-neutral-500 dark:text-neutral-400 hover:text-neutral-700 dark:hover:text-neutral-300 transition-colors"
              >
                @{post.author?.username}
              </button>
            </div>
          </div>

          {/* Article Header Section */}
          <div className="mb-8">
            {/* Article Type Badge */}
            <div className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-neutral-100 dark:bg-neutral-800 rounded-md mb-6">
              <BookOpen className="w-4 h-4 text-neutral-600 dark:text-neutral-400" />
              <span className="text-xs font-semibold text-neutral-700 dark:text-neutral-300 uppercase tracking-wider">
                Article
              </span>
            </div>

            {/* Title */}
            <h1 className="text-4xl md:text-5xl font-bold text-neutral-900 dark:text-neutral-50 mb-6 leading-tight tracking-tight">
              {article.title}
            </h1>

            {/* Subtitle */}
            {article.subtitle && (
              <p className="text-xl md:text-2xl text-neutral-600 dark:text-neutral-400 mb-8 leading-relaxed font-light">
                {article.subtitle}
              </p>
            )}

            {/* Meta Information */}
            <div className="flex items-center gap-5 text-sm text-neutral-500 dark:text-neutral-400 pb-8 border-b border-neutral-200 dark:border-neutral-800">
              <div className="flex items-center gap-2">
                <Clock className="w-4 h-4" />
                <span className="font-medium">{article.read_time_minutes} min read</span>
              </div>
              {article.category && (
                <>
                  <span className="text-neutral-300 dark:text-neutral-600">·</span>
                  <span className="font-medium text-neutral-700 dark:text-neutral-300">{article.category}</span>
                </>
              )}
              {article.views_count > 0 && (
                <>
                  <span className="text-neutral-300 dark:text-neutral-600">·</span>
                  <span>{article.views_count.toLocaleString()} views</span>
                </>
              )}
            </div>
          </div>

          {/* Article Content - Justified and Professional */}
          <div className="article-content">
            <div 
              className="prose prose-xl dark:prose-invert max-w-none break-words overflow-wrap-anywhere
                prose-headings:font-bold prose-headings:text-neutral-900 dark:prose-headings:text-neutral-50
                prose-headings:mt-12 prose-headings:mb-6
                prose-h1:text-3xl prose-h1:font-bold prose-h1:leading-tight
                prose-h2:text-2xl prose-h2:font-bold prose-h2:mt-10 prose-h2:mb-5
                prose-h3:text-xl prose-h3:font-semibold prose-h3:mt-8 prose-h3:mb-4
                prose-p:text-neutral-700 dark:prose-p:text-neutral-300
                prose-p:text-lg prose-p:leading-relaxed prose-p:mb-6
                prose-p:text-justify
                prose-a:text-purple-600 dark:prose-a:text-purple-400
                prose-a:font-medium prose-a:no-underline hover:prose-a:underline
                prose-strong:text-neutral-900 dark:prose-strong:text-neutral-50
                prose-strong:font-semibold
                prose-code:text-purple-600 dark:prose-code:text-purple-400
                prose-code:bg-neutral-100 dark:prose-code:bg-neutral-800
                prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded
                prose-pre:bg-neutral-100 dark:prose-pre:bg-neutral-900
                prose-pre:border prose-pre:border-neutral-200 dark:prose-pre:border-neutral-800
                prose-pre:rounded-lg prose-pre:p-4
                prose-img:rounded-xl prose-img:my-8 prose-img:shadow-lg
                prose-img:w-full prose-img:h-auto
                prose-blockquote:border-l-4 prose-blockquote:border-l-purple-600 dark:prose-blockquote:border-l-purple-400
                prose-blockquote:bg-neutral-50 dark:prose-blockquote:bg-neutral-900/50
                prose-blockquote:pl-6 prose-blockquote:pr-4 prose-blockquote:py-4 prose-blockquote:my-6
                prose-blockquote:text-neutral-700 dark:prose-blockquote:text-neutral-300
                prose-blockquote:italic
                prose-ul:my-6 prose-ul:pl-6
                prose-ol:my-6 prose-ol:pl-6
                prose-li:my-3 prose-li:text-lg prose-li:leading-relaxed
                prose-li:text-justify
                prose-hr:my-10 prose-hr:border-neutral-200 dark:prose-hr:border-neutral-800"
              dangerouslySetInnerHTML={{ __html: processedHtml || article.content_html }}
              style={{
                textAlign: 'justify',
                textJustify: 'inter-word',
              }}
            />
          </div>

          {/* Footer Actions */}
          <div className="mt-12 pt-8 border-t border-neutral-200 dark:border-neutral-800">
            <PostActions
              postId={post.id}
              isLiked={post.is_liked}
              isSaved={post.is_saved}
              likesCount={post.likes_count}
              commentsCount={post.comments_count}
              sharesCount={post.shares_count}
              onComment={() => setShowCommentModal(true)}
              onShare={handleShare}
              onSave={() => onSave?.(post)}
            />
          </div>
            </div>
            
            {/* Table of Contents Sidebar */}
            {article.content_html && (
              <div className="w-64 flex-shrink-0">
                <TableOfContents contentHtml={article.content_html} />
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Comment Modal */}
      <CommentModal
        post={post}
        isOpen={showCommentModal}
        onClose={() => setShowCommentModal(false)}
      />
    </div>
  );
}
