'use client';

import { useState, useRef, useEffect } from 'react';
import { Globe, Users, Lock, Loader2 } from 'lucide-react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { postsAPI, CreatePostRequest, Post } from '@/lib/api/posts';
import { toast } from '../ui/Toast';
import { Avatar } from '../ui/Avatar';
import MediaUploader, { type ImageUpload, type VideoUpload, type AudioUpload } from './MediaUploader';
import { mediaAPI } from '@/lib/api/media';
import { useOptimisticPost } from '@/lib/hooks/useOptimisticPost';

interface TextPostComposerProps {
  onClose: () => void;
  onPostCreated?: (post: any) => void;
}

export default function TextPostComposer({ onClose, onPostCreated }: TextPostComposerProps) {
  const queryClient = useQueryClient();
  const { createOptimisticPost, addOptimisticPostToFeed, replaceOptimisticPost, removeOptimisticPost } = useOptimisticPost();
  
  const [content, setContent] = useState('');
  const [visibility, setVisibility] = useState<'public' | 'connections' | 'private'>('public');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [mediaFiles, setMediaFiles] = useState<{
    images: ImageUpload[];
    videos: VideoUpload[];
    audios: AudioUpload[];
  }>({
    images: [],
    videos: [],
    audios: [],
  });
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  
  // Auto-resize textarea
  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
      textareaRef.current.style.height = textareaRef.current.scrollHeight + 'px';
    }
  }, [content]);

  const handleSubmit = async () => {
    if (!content.trim() && mediaFiles.images.length === 0 && mediaFiles.videos.length === 0 && mediaFiles.audios.length === 0) {
      toast.error('Post content or media is required');
      return;
    }

    if (content.length > 3000) {
      toast.error('Post must be 3000 characters or less');
      return;
    }

    setIsSubmitting(true);

    try {
      // Upload media files
      const mediaUrls: string[] = [];
      const mediaTypes: string[] = [];

      // Upload images
      for (const image of mediaFiles.images) {
        const fileToUpload = image.compressed || image.file;
        try {
          const result = await mediaAPI.uploadImage(fileToUpload, (progress) => {
            // Update progress if needed
          });
          mediaUrls.push(result.url);
          mediaTypes.push('image');
        } catch (error) {
          console.error('Failed to upload image:', error);
          toast.error(`Failed to upload image: ${image.file.name}`);
        }
      }

      // Upload videos
      for (const video of mediaFiles.videos) {
        const fileToUpload = video.compressed ? new File([video.compressed], video.file.name, { type: video.file.type }) : video.file;
        try {
          const result = await mediaAPI.uploadVideo(fileToUpload, (progress) => {
            // Update progress if needed
          });
          mediaUrls.push(result.url);
          mediaTypes.push('video');
        } catch (error) {
          console.error('Failed to upload video:', error);
          toast.error(`Failed to upload video: ${video.file.name}`);
        }
      }

      // Upload audios
      for (const audio of mediaFiles.audios) {
        const fileToUpload = audio.compressed ? new File([audio.compressed], audio.file.name, { type: audio.file.type }) : audio.file;
        try {
          const result = await mediaAPI.uploadAudio(fileToUpload, (progress) => {
            // Update progress if needed
          });
          mediaUrls.push(result.url);
          mediaTypes.push('audio');
        } catch (error) {
          console.error('Failed to upload audio:', error);
          toast.error(`Failed to upload audio: ${audio.file.name}`);
        }
      }

      const postData: CreatePostRequest = {
        post_type: 'post',
        content: content.trim(),
        media_urls: mediaUrls.length > 0 ? mediaUrls : undefined,
        media_types: mediaTypes.length > 0 ? mediaTypes : undefined,
        visibility,
        allows_comments: true,
        allows_sharing: true,
        is_draft: false,
      };

      // Optimistic post creation
      const optimisticPost = createOptimisticPost(postData);
      addOptimisticPostToFeed('home', optimisticPost);
      const tempId = optimisticPost.id;

      try {
        const response = await postsAPI.createPost(postData);

        if (response.success && response.post) {
          // Replace optimistic post with real one
          replaceOptimisticPost('home', tempId, response.post);
          
          // Also invalidate other feeds
          queryClient.invalidateQueries({ queryKey: ['feed'] });
          
          toast.success('Post published successfully!');
          onPostCreated?.(response.post);
          onClose();
        } else {
          // Remove optimistic post if no post returned
          removeOptimisticPost('home', tempId);
          throw new Error('Failed to create post');
        }
      } catch (error) {
        // Remove optimistic post on error
        removeOptimisticPost('home', tempId);
        throw error;
      }
    } catch (error) {
      console.error('Failed to create post:', error);
      toast.error('Failed to publish post');
    } finally {
      setIsSubmitting(false);
    }
  };

  const charCount = content.length;
  const charLimit = 3000;
  const isOverLimit = charCount > charLimit;

  return (
    <div className="p-4 md:p-6 space-y-3 md:space-y-4">
      {/* User Info */}
      <div className="flex items-center gap-3">
        <Avatar 
          src={null} 
          alt="You" 
          fallback="You"
          size="md"
        />
        <div>
          <p className="font-semibold text-neutral-900 dark:text-neutral-50">Share your thoughts</p>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">
            What's on your mind?
          </p>
        </div>
      </div>

      {/* Content Input */}
      <div className="space-y-2">
        <textarea
          ref={textareaRef}
          value={content}
          onChange={(e) => setContent(e.target.value)}
          placeholder="What do you want to share today? Use #hashtags and @mentions..."
          className="w-full min-h-[120px] md:min-h-[150px] px-3 md:px-4 py-3 bg-white dark:bg-neutral-800 border-2 border-neutral-200 dark:border-neutral-700 rounded-xl text-black dark:text-white placeholder:text-neutral-400 dark:placeholder:text-neutral-500 focus:outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 resize-none transition-all cursor-text"
          autoFocus
        />
        
        {/* Character Counter */}
        <div className="flex justify-between items-center text-sm">
          <div className="text-neutral-500 dark:text-neutral-400">
            Tip: Use #hashtags to reach more people
          </div>
          <div className={`font-medium ${isOverLimit ? 'text-red-500' : 'text-neutral-500'}`}>
            {charCount} / {charLimit}
          </div>
        </div>
      </div>

      {/* Media Uploader */}
      <div className="space-y-3">
        <MediaUploader
          onMediaChange={(media) => {
            // Store media for upload
            setMediaFiles(media);
          }}
          maxImages={10}
          maxVideos={1}
          maxAudios={5}
          imageQuality="standard"
          videoQuality="standard"
          audioType="music"
        />
      </div>

      {/* Visibility Selector */}
      <div className="flex items-center justify-between p-4 bg-transparent border-2 border-neutral-200 dark:border-neutral-700 rounded-xl hover:border-neutral-300 dark:hover:border-neutral-600 transition-colors">
        <div className="flex items-center gap-3">
          {visibility === 'public' && <Globe className="w-5 h-5 text-purple-600 dark:text-purple-400" />}
          {visibility === 'connections' && <Users className="w-5 h-5 text-purple-600 dark:text-purple-400" />}
          {visibility === 'private' && <Lock className="w-5 h-5 text-purple-600 dark:text-purple-400" />}
          <div>
            <p className="text-sm font-medium text-black dark:text-white">
              {visibility === 'public' && 'Everyone'}
              {visibility === 'connections' && 'Connections only'}
              {visibility === 'private' && 'Only me'}
            </p>
            <p className="text-xs text-neutral-500 dark:text-neutral-400">
              {visibility === 'public' && 'Anyone can see this post'}
              {visibility === 'connections' && 'Only your connections can see'}
              {visibility === 'private' && 'Only you can see this'}
            </p>
          </div>
        </div>
        <select
          value={visibility}
          onChange={(e) => setVisibility(e.target.value as any)}
          className="px-4 py-2 bg-neutral-50 dark:bg-neutral-800 border-2 border-neutral-200 dark:border-neutral-700 rounded-lg text-sm font-medium text-black dark:text-white focus:outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 cursor-pointer transition-all hover:border-purple-400"
        >
          <option value="public">Everyone</option>
          <option value="connections">Connections</option>
          <option value="private">Private</option>
        </select>
      </div>

      {/* Actions */}
      <div className="flex items-center justify-end gap-3 pt-3 md:pt-4 border-t border-neutral-200 dark:border-neutral-800">
        <button
          onClick={onClose}
          className="px-5 py-2.5 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-100 dark:hover:bg-neutral-800 rounded-lg transition-colors font-medium"
          disabled={isSubmitting}
        >
          Cancel
        </button>
        <button
          onClick={handleSubmit}
          disabled={!content.trim() || isOverLimit || isSubmitting}
          className="px-6 py-2.5 bg-purple-600 hover:bg-purple-700 text-white rounded-lg transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
        >
          {isSubmitting ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              Publishing...
            </>
          ) : (
            'Publish Post'
          )}
        </button>
      </div>
    </div>
  );
}

