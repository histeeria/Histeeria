import { Metadata } from 'next';
import { Post, Article } from '@/lib/api/posts';

export function generateArticleMetadata(post: Post | null): Metadata {
  if (!post || !post.article) {
    return {
      title: 'Article Not Found | UpVista Community',
      description: 'The article you are looking for does not exist.',
    };
  }

  const article = post.article;
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || 'https://upvista.com';
  const articleUrl = `${siteUrl}/articles/${article.slug}`;
  const coverImage = article.cover_image_url || `${siteUrl}/assets/u.png`;
  const authorName = post.author?.display_name || post.author?.username || 'UpVista Author';
  const description = article.meta_description || article.subtitle || `${article.title} - Read on UpVista Community`;

  return {
    title: article.meta_title || article.title,
    description,
    authors: [{ name: authorName }],
    openGraph: {
      title: article.meta_title || article.title,
      description,
      url: articleUrl,
      siteName: 'UpVista Community',
      images: [
        {
          url: coverImage,
          width: 1200,
          height: 630,
          alt: article.title,
        },
      ],
      locale: 'en_US',
      type: 'article',
      publishedTime: post.created_at,
      modifiedTime: article.updated_at,
      authors: [authorName],
      section: article.category,
      tags: article.tags || [],
    },
    twitter: {
      card: 'summary_large_image',
      title: article.meta_title || article.title,
      description,
      images: [coverImage],
      creator: `@${post.author?.username || 'upvista'}`,
    },
    alternates: {
      canonical: articleUrl,
    },
    other: {
      'article:author': authorName,
      'article:published_time': post.created_at,
      'article:modified_time': article.updated_at,
      'article:section': article.category || '',
      'article:tag': (article.tags || []).join(','),
      'article:reading_time': `${article.read_time_minutes} minutes`,
    },
  };
}

