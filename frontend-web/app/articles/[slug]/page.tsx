import { Metadata } from 'next';
import { MainLayout } from '@/components/layout/MainLayout';
import ArticleView from '@/components/posts/ArticleView';
import { generateArticleMetadata } from './metadata';
import { Post } from '@/lib/api/posts';

type PageProps = {
  params: { slug: string };
      };

async function fetchArticleBySlug(slug: string): Promise<Post | null> {
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || 'http://localhost:3001';
  const res = await fetch(`${siteUrl}/api/proxy/v1/articles/${encodeURIComponent(slug)}`, {
    method: 'GET',
    cache: 'no-store',
    // Edge cases: allow failures to be handled gracefully
    next: { revalidate: 0 },
  });

  if (!res.ok) {
    return null;
  }

  const data = await res.json();
  const post: Post | undefined = data.post || data.Post;
  return data.success && post ? post : null;
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const post = await fetchArticleBySlug(params.slug);
  return generateArticleMetadata(post);
}

export default async function ArticlePage({ params }: PageProps) {
  const post = await fetchArticleBySlug(params.slug);

  if (!post) {
    return (
      <MainLayout>
        <div className="min-h-screen flex items-center justify-center">
          <div className="text-center max-w-md">
            <h1 className="text-2xl font-bold text-neutral-900 dark:text-neutral-50 mb-2">
              Article Not Found
            </h1>
            <p className="text-neutral-600 dark:text-neutral-400 mb-6">
              The article you're looking for doesn't exist or has been removed.
            </p>
            <a
              href="/home"
              className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors inline-block"
            >
              Go to Home
            </a>
          </div>
        </div>
      </MainLayout>
    );
  }

  if (!post.article) {
    return (
      <MainLayout>
        <div className="min-h-screen flex items-center justify-center">
          <div className="text-center">
            <p className="text-neutral-600 dark:text-neutral-400">
              This post is not an article.
            </p>
          </div>
        </div>
      </MainLayout>
    );
  }

  return (
    <MainLayout>
      <div className="min-h-screen bg-white dark:bg-gray-900">
        <ArticleView post={post} />
      </div>
    </MainLayout>
  );
}

