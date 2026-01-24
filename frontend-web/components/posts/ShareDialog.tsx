'use client';

import { useState } from 'react';
import { X, Twitter, Facebook, Linkedin, MessageCircle, Mail, Link2, Copy, Check, QrCode } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { Post } from '@/lib/api/posts';
import {
  getTwitterShareLink,
  getFacebookShareLink,
  getLinkedInShareLink,
  getWhatsAppShareLink,
  getTelegramShareLink,
  getEmailShareLink,
  copyToClipboard,
  getQRCodeUrl,
  type ShareOptions,
} from '@/lib/utils/shareLinks';
import { toast } from '../ui/Toast';

interface ShareDialogProps {
  post: Post;
  isOpen: boolean;
  onClose: () => void;
}

export function ShareDialog({ post, isOpen, onClose }: ShareDialogProps) {
  const [copied, setCopied] = useState(false);
  const [showQR, setShowQR] = useState(false);

  if (!isOpen) return null;

  const siteUrl = typeof window !== 'undefined' ? window.location.origin : '';
  const postUrl = `${siteUrl}/posts/${post.id}`;
  const articleUrl = post.article ? `${siteUrl}/articles/${post.article.slug}` : postUrl;
  const shareUrl = post.article ? articleUrl : postUrl;

  const title = post.article?.title || post.content?.substring(0, 100) || 'Check this out';
  const description = post.article?.subtitle || post.content?.substring(0, 200) || '';
  const image = post.article?.cover_image_url || (post.media_urls && post.media_urls[0]) || '';

  const shareOptions: ShareOptions = {
    url: shareUrl,
    title,
    description,
    image,
    hashtags: post.hashtags || [],
  };

  const handleCopyLink = async () => {
    const success = await copyToClipboard(shareUrl);
    if (success) {
      setCopied(true);
      toast.success('Link copied to clipboard!');
      setTimeout(() => setCopied(false), 2000);
    } else {
      toast.error('Failed to copy link');
    }
  };

  const handleShare = (platform: string, url: string) => {
    window.open(url, '_blank', 'width=600,height=400');
    onClose();
  };

  const platforms = [
    {
      id: 'twitter',
      name: 'Twitter/X',
      icon: Twitter,
      color: 'text-blue-400',
      bgColor: 'bg-blue-50 dark:bg-blue-900/20',
      getUrl: () => getTwitterShareLink(shareOptions),
    },
    {
      id: 'facebook',
      name: 'Facebook',
      icon: Facebook,
      color: 'text-blue-600',
      bgColor: 'bg-blue-50 dark:bg-blue-900/20',
      getUrl: () => getFacebookShareLink(shareOptions),
    },
    {
      id: 'linkedin',
      name: 'LinkedIn',
      icon: Linkedin,
      color: 'text-blue-700',
      bgColor: 'bg-blue-50 dark:bg-blue-900/20',
      getUrl: () => getLinkedInShareLink(shareOptions),
    },
    {
      id: 'whatsapp',
      name: 'WhatsApp',
      icon: MessageCircle,
      color: 'text-green-600',
      bgColor: 'bg-green-50 dark:bg-green-900/20',
      getUrl: () => getWhatsAppShareLink(shareOptions),
    },
    {
      id: 'telegram',
      name: 'Telegram',
      icon: MessageCircle,
      color: 'text-blue-500',
      bgColor: 'bg-blue-50 dark:bg-blue-900/20',
      getUrl: () => getTelegramShareLink(shareOptions),
    },
    {
      id: 'email',
      name: 'Email',
      icon: Mail,
      color: 'text-neutral-600',
      bgColor: 'bg-neutral-50 dark:bg-neutral-800',
      getUrl: () => getEmailShareLink(shareOptions),
    },
  ];

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-[400] flex items-center justify-center p-4">
        {/* Backdrop */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="absolute inset-0 bg-black/50 backdrop-blur-sm"
          onClick={onClose}
        />

        {/* Dialog */}
        <motion.div
          initial={{ opacity: 0, scale: 0.95, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 20 }}
          transition={{ duration: 0.2 }}
          className="relative w-full max-w-md
            bg-white/90 dark:bg-neutral-900/90
            backdrop-blur-2xl
            border border-white/30 dark:border-neutral-700/30
            rounded-2xl shadow-2xl
            overflow-hidden
          "
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="flex items-center justify-between px-6 py-4 border-b border-white/20 dark:border-neutral-700/30">
            <h2 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50">
              Share Post
            </h2>
            <motion.button
              whileTap={{ scale: 0.9 }}
              onClick={onClose}
              className="p-2 rounded-full hover:bg-white/50 dark:hover:bg-neutral-800/50 transition-colors"
            >
              <X className="w-5 h-5 text-neutral-600 dark:text-neutral-400" />
            </motion.button>
          </div>

          {/* Content */}
          <div className="p-6">
            {/* Platform Grid */}
            <div className="grid grid-cols-3 gap-3 mb-6">
              {platforms.map((platform) => {
                const Icon = platform.icon;
                return (
                  <motion.button
                    key={platform.id}
                    whileTap={{ scale: 0.95 }}
                    onClick={() => handleShare(platform.name, platform.getUrl())}
                    className={`
                      flex flex-col items-center justify-center gap-2 p-4 rounded-xl
                      ${platform.bgColor}
                      border border-white/30 dark:border-neutral-700/30
                      hover:scale-105 transition-all duration-200
                    `}
                  >
                    <Icon className={`w-6 h-6 ${platform.color}`} />
                    <span className="text-xs font-medium text-neutral-700 dark:text-neutral-300">
                      {platform.name}
                    </span>
                  </motion.button>
                );
              })}
            </div>

            {/* Copy Link */}
            <div className="space-y-3">
              <div className="flex items-center gap-2 p-3 rounded-lg bg-neutral-50 dark:bg-neutral-800 border border-neutral-200 dark:border-neutral-700">
                <Link2 className="w-4 h-4 text-neutral-500 dark:text-neutral-400 flex-shrink-0" />
                <input
                  type="text"
                  value={shareUrl}
                  readOnly
                  className="flex-1 bg-transparent text-sm text-neutral-900 dark:text-neutral-50 outline-none"
                />
                <motion.button
                  whileTap={{ scale: 0.9 }}
                  onClick={handleCopyLink}
                  className="p-2 rounded-lg bg-purple-100 dark:bg-purple-900/30 hover:bg-purple-200 dark:hover:bg-purple-900/50 transition-colors"
                >
                  {copied ? (
                    <Check className="w-4 h-4 text-green-600 dark:text-green-400" />
                  ) : (
                    <Copy className="w-4 h-4 text-purple-600 dark:text-purple-400" />
                  )}
                </motion.button>
              </div>

              {/* QR Code */}
              <motion.button
                whileTap={{ scale: 0.95 }}
                onClick={() => setShowQR(!showQR)}
                className="w-full flex items-center justify-center gap-2 p-3 rounded-lg
                  bg-neutral-50 dark:bg-neutral-800
                  border border-neutral-200 dark:border-neutral-700
                  hover:bg-neutral-100 dark:hover:bg-neutral-700
                  transition-colors
                "
              >
                <QrCode className="w-4 h-4 text-neutral-600 dark:text-neutral-400" />
                <span className="text-sm font-medium text-neutral-700 dark:text-neutral-300">
                  {showQR ? 'Hide' : 'Show'} QR Code
                </span>
              </motion.button>

              {/* QR Code Display */}
              <AnimatePresence>
                {showQR && (
                  <motion.div
                    initial={{ opacity: 0, height: 0 }}
                    animate={{ opacity: 1, height: 'auto' }}
                    exit={{ opacity: 0, height: 0 }}
                    className="flex justify-center p-4 bg-neutral-50 dark:bg-neutral-800 rounded-lg"
                  >
                    <img
                      src={getQRCodeUrl(shareUrl, 200)}
                      alt="QR Code"
                      className="w-48 h-48"
                    />
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
}

