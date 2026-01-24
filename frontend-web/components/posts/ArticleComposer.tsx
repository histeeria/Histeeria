'use client';

import { useState } from 'react';
import { useEditor, EditorContent } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import Link from '@tiptap/extension-link';
import Image from '@tiptap/extension-image';
import Placeholder from '@tiptap/extension-placeholder';
import CodeBlockLowlight from '@tiptap/extension-code-block-lowlight';
import { common, createLowlight } from 'lowlight';

const lowlight = createLowlight(common);
import { 
  Bold, Italic, List, ListOrdered, Code, Quote, 
  Heading1, Heading2, Heading3, Link as LinkIcon,
  Image as ImageIcon, Loader2, X, Upload, Globe, Users, Lock
} from 'lucide-react';
import { postsAPI, CreatePostRequest, CreateArticleRequest } from '@/lib/api/posts';
import { toast } from '../ui/Toast';

interface ArticleComposerProps {
  onClose: () => void;
  onPostCreated?: (post: any) => void;
}

export default function ArticleComposer({ onClose, onPostCreated }: ArticleComposerProps) {
  const [title, setTitle] = useState('');
  const [subtitle, setSubtitle] = useState('');
  const [coverImage, setCoverImage] = useState('');
  const [category, setCategory] = useState('');
  const [tags, setTags] = useState<string[]>([]);
  const [tagInput, setTagInput] = useState('');
  const [visibility, setVisibility] = useState<'public' | 'connections' | 'private'>('public');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const editor = useEditor({
    immediatelyRender: false, // Fix SSR hydration mismatch
    extensions: [
      StarterKit.configure({
        codeBlock: false, // Use CodeBlockLowlight instead
      }),
      Link.configure({
        openOnClick: false,
        HTMLAttributes: {
          class: 'text-purple-600 dark:text-purple-400 hover:underline',
        },
      }),
      Image.configure({
        HTMLAttributes: {
          class: 'rounded-lg max-w-full h-auto my-4',
        },
      }),
      Placeholder.configure({
        placeholder: 'Start writing your article... Use formatting tools above.',
      }),
      CodeBlockLowlight.configure({
        lowlight,
        HTMLAttributes: {
          class: 'bg-neutral-900 dark:bg-neutral-950 text-neutral-100 rounded-lg p-4 my-4 overflow-x-auto',
        },
      }),
    ],
    editorProps: {
      attributes: {
        class: 'prose prose-neutral dark:prose-invert max-w-none focus:outline-none min-h-[180px] md:min-h-[400px] px-3 md:px-4 py-3 text-justify',
      },
    },
  });

  const handleSubmit = async () => {
    if (!title.trim()) {
      toast.error('Please enter a title');
      return;
    }

    if (!editor || editor.isEmpty) {
      toast.error('Please add some content to your article');
      return;
    }

    setIsSubmitting(true);

    try {
      const contentHTML = editor.getHTML();
      
      const articleData: CreateArticleRequest = {
        title: title.trim(),
        subtitle: subtitle.trim() || undefined,
        content_html: contentHTML,
        cover_image_url: coverImage || undefined,
        category: category || undefined,
        tags: tags.length > 0 ? tags : undefined,
      };

      const postData: CreatePostRequest = {
        post_type: 'article',
        content: title.trim(), // Use title as content for search
        visibility,
        allows_comments: true,
        allows_sharing: true,
        article: articleData,
      };

      const response = await postsAPI.createPost(postData);

      if (response.success) {
        toast.success('Article published successfully!');
        onPostCreated?.(response.post);
        onClose();
      }
    } catch (error) {
      console.error('Failed to create article:', error);
      toast.error('Failed to publish article');
    } finally {
      setIsSubmitting(false);
    }
  };

  const addTag = () => {
    if (tagInput.trim() && tags.length < 5 && !tags.includes(tagInput.trim().toLowerCase())) {
      setTags([...tags, tagInput.trim().toLowerCase()]);
      setTagInput('');
    }
  };

  const removeTag = (tag: string) => {
    setTags(tags.filter(t => t !== tag));
  };

  const addLink = () => {
    if (editor) {
      const url = window.prompt('Enter URL:');
      if (url) {
        editor.chain().focus().setLink({ href: url }).run();
      }
    }
  };

  const addImage = () => {
    if (editor) {
      const url = window.prompt('Enter image URL:');
      if (url) {
        editor.chain().focus().setImage({ src: url }).run();
      }
    }
  };

  return (
    <div className="flex flex-col h-full">
      {/* Metadata Section */}
      <div className="p-6 space-y-4 border-b border-neutral-200 dark:border-neutral-800">
        {/* Title */}
        <div>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Article Title"
            className="w-full px-4 py-3 text-2xl font-bold bg-transparent border-none text-black dark:text-white placeholder:text-neutral-400 dark:placeholder:text-neutral-500 focus:outline-none cursor-text"
            maxLength={100}
          />
          <div className="text-right text-sm text-neutral-500">
            {title.length}/100
          </div>
        </div>

        {/* Subtitle */}
        <input
          type="text"
          value={subtitle}
          onChange={(e) => setSubtitle(e.target.value)}
          placeholder="Subtitle (optional)"
          className="w-full px-4 py-2 text-lg bg-white dark:bg-neutral-800 border-2 border-neutral-200 dark:border-neutral-700 rounded-lg text-black dark:text-white placeholder:text-neutral-400 dark:placeholder:text-neutral-500 focus:outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 transition-all cursor-text"
          maxLength={150}
        />

        {/* Cover Image */}
        <div className="flex gap-2">
          <input
            type="url"
            value={coverImage}
            onChange={(e) => setCoverImage(e.target.value)}
            placeholder="Cover image URL (1200x627 recommended)"
            className="flex-1 px-4 py-2 bg-white dark:bg-neutral-800 border-2 border-neutral-200 dark:border-neutral-700 rounded-lg text-black dark:text-white placeholder:text-neutral-400 dark:placeholder:text-neutral-500 text-sm focus:outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 transition-all cursor-text"
          />
          <button
            onClick={() => toast.info('Upload feature coming soon')}
            className="px-4 py-2 bg-neutral-100 dark:bg-neutral-800 hover:bg-neutral-200 dark:hover:bg-neutral-700 rounded-lg transition-colors"
          >
            <Upload className="w-4 h-4" />
          </button>
        </div>

        {/* Category & Tags */}
        <div className="flex gap-2">
          <input
            type="text"
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            placeholder="Category (e.g., Technology)"
            className="flex-1 px-4 py-2 bg-white dark:bg-neutral-800 border-2 border-neutral-200 dark:border-neutral-700 rounded-lg text-black dark:text-white placeholder:text-neutral-400 dark:placeholder:text-neutral-500 text-sm focus:outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 transition-all cursor-text"
            maxLength={50}
          />
        </div>

        {/* Tags */}
        <div className="space-y-2">
          <div className="flex flex-wrap gap-2">
            {tags.map((tag) => (
              <span
                key={tag}
                className="px-3 py-1 bg-purple-100 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300 rounded-full text-sm flex items-center gap-1"
              >
                #{tag}
                <button
                  onClick={() => removeTag(tag)}
                  className="hover:text-purple-900 dark:hover:text-purple-100"
                >
                  <X className="w-3 h-3" />
                </button>
              </span>
            ))}
          </div>
          {tags.length < 5 && (
            <div className="flex gap-2">
              <input
                type="text"
                value={tagInput}
                onChange={(e) => setTagInput(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addTag())}
                placeholder="Add tags (max 5)"
                className="flex-1 px-4 py-2 bg-white dark:bg-neutral-800 border-2 border-neutral-200 dark:border-neutral-700 rounded-lg text-black dark:text-white placeholder:text-neutral-400 dark:placeholder:text-neutral-500 text-sm focus:outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 transition-all cursor-text"
              />
              <button
                onClick={addTag}
                disabled={!tagInput.trim() || tags.length >= 5}
                className="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-lg text-sm font-medium disabled:opacity-50"
              >
                Add
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Editor Toolbar */}
      {editor && (
        <div className="flex items-center gap-1 px-3 md:px-6 py-2.5 md:py-3 border-b border-neutral-200 dark:border-neutral-800 overflow-x-auto">
          <button
            onClick={() => editor.chain().focus().toggleHeading({ level: 1 }).run()}
            className={`p-2 rounded hover:bg-neutral-100 dark:hover:bg-neutral-800 ${
              editor.isActive('heading', { level: 1 }) ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-600' : ''
            }`}
            title="Heading 1"
          >
            <Heading1 className="w-4 h-4" />
          </button>
          <button
            onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()}
            className={`p-2 rounded hover:bg-neutral-100 dark:hover:bg-neutral-800 ${
              editor.isActive('heading', { level: 2 }) ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-600' : ''
            }`}
            title="Heading 2"
          >
            <Heading2 className="w-4 h-4" />
          </button>
          <button
            onClick={() => editor.chain().focus().toggleHeading({ level: 3 }).run()}
            className={`p-2 rounded hover:bg-neutral-100 dark:hover:bg-neutral-800 ${
              editor.isActive('heading', { level: 3 }) ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-600' : ''
            }`}
            title="Heading 3"
          >
            <Heading3 className="w-4 h-4" />
          </button>

          <div className="w-px h-6 bg-neutral-300 dark:bg-neutral-700 mx-1" />

          <button
            onClick={() => editor.chain().focus().toggleBold().run()}
            className={`p-2 rounded hover:bg-neutral-100 dark:hover:bg-neutral-800 ${
              editor.isActive('bold') ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-600' : ''
            }`}
            title="Bold"
          >
            <Bold className="w-4 h-4" />
          </button>
          <button
            onClick={() => editor.chain().focus().toggleItalic().run()}
            className={`p-2 rounded hover:bg-neutral-100 dark:hover:bg-neutral-800 ${
              editor.isActive('italic') ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-600' : ''
            }`}
            title="Italic"
          >
            <Italic className="w-4 h-4" />
          </button>
          <button
            onClick={() => editor.chain().focus().toggleCode().run()}
            className={`p-2 rounded hover:bg-neutral-100 dark:hover:bg-neutral-800 ${
              editor.isActive('code') ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-600' : ''
            }`}
            title="Inline Code"
          >
            <Code className="w-4 h-4" />
          </button>

          <div className="w-px h-6 bg-neutral-300 dark:bg-neutral-700 mx-1" />

          <button
            onClick={() => editor.chain().focus().toggleBulletList().run()}
            className={`p-2 rounded hover:bg-neutral-100 dark:hover:bg-neutral-800 ${
              editor.isActive('bulletList') ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-600' : ''
            }`}
            title="Bullet List"
          >
            <List className="w-4 h-4" />
          </button>
          <button
            onClick={() => editor.chain().focus().toggleOrderedList().run()}
            className={`p-2 rounded hover:bg-neutral-100 dark:hover:bg-neutral-800 ${
              editor.isActive('orderedList') ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-600' : ''
            }`}
            title="Numbered List"
          >
            <ListOrdered className="w-4 h-4" />
          </button>
          <button
            onClick={() => editor.chain().focus().toggleBlockquote().run()}
            className={`p-2 rounded hover:bg-neutral-100 dark:hover:bg-neutral-800 ${
              editor.isActive('blockquote') ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-600' : ''
            }`}
            title="Quote"
          >
            <Quote className="w-4 h-4" />
          </button>

          <div className="w-px h-6 bg-neutral-300 dark:bg-neutral-700 mx-1" />

          <button
            onClick={addLink}
            className="p-2 rounded hover:bg-neutral-100 dark:hover:bg-neutral-800"
            title="Add Link"
          >
            <LinkIcon className="w-4 h-4" />
          </button>
          <button
            onClick={addImage}
            className="p-2 rounded hover:bg-neutral-100 dark:hover:bg-neutral-800"
            title="Add Image"
          >
            <ImageIcon className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* Editor Content */}
      <div className="flex-1 overflow-y-auto px-3 md:px-6 py-3 md:py-4 bg-neutral-50/50 dark:bg-neutral-900/50">
        <EditorContent editor={editor} />
      </div>

      {/* Footer */}
      <div className="px-3 md:px-6 py-3 md:py-4 border-t border-neutral-200 dark:border-neutral-800 space-y-3 md:space-y-4">
        {/* Visibility */}
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
                {visibility === 'public' && 'Anyone can see this article'}
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
        <div className="flex items-center justify-between">
          <div className="text-sm text-neutral-500">
            {editor && !editor.isEmpty && (
              <span>~{Math.ceil(editor.getText().split(' ').length / 200)} min read</span>
            )}
          </div>
          <div className="flex gap-3">
            <button
              onClick={onClose}
              className="px-5 py-2.5 text-neutral-700 dark:text-neutral-300 hover:bg-neutral-100 dark:hover:bg-neutral-800 rounded-lg transition-colors font-medium"
              disabled={isSubmitting}
            >
              Cancel
            </button>
            <button
              onClick={handleSubmit}
              disabled={!title.trim() || !editor || editor.isEmpty || isSubmitting}
              className="px-6 py-2.5 bg-purple-600 hover:bg-purple-700 text-white rounded-lg transition-colors font-medium disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  Publishing...
                </>
              ) : (
                'Publish Article'
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

