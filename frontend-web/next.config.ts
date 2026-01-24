import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  experimental: {
    // Enable view transitions for smooth page changes (Instagram-style)
    viewTransition: true,
    // Optimize package imports for better code splitting
    optimizePackageImports: [
      'lucide-react', 
      'framer-motion', 
      '@tiptap/react',
      'react-icons',
      'date-fns',
    ],
  },
  // Production optimizations
  productionBrowserSourceMaps: false, // Disable source maps in production
  poweredByHeader: false, // Remove X-Powered-By header
  compress: true, // Enable gzip compression
  
  // Code splitting configuration
  webpack: (config, { isServer }) => {
    if (!isServer) {
      // Split large libraries into separate chunks
      config.optimization = {
        ...config.optimization,
        splitChunks: {
          chunks: 'all',
          cacheGroups: {
            // Vendor chunks
            vendor: {
              test: /[\\/]node_modules[\\/]/,
              name(module: any) {
                const packageName = module.context.match(
                  /[\\/]node_modules[\\/](.*?)([\\/]|$)/
                )?.[1];
                return `vendor.${packageName?.replace('@', '')}`;
              },
              priority: 10,
            },
            // TipTap editor (large)
            tiptap: {
              test: /[\\/]node_modules[\\/]@tiptap/,
              name: 'tiptap',
              priority: 20,
            },
            // React Query
            reactQuery: {
              test: /[\\/]node_modules[\\/]@tanstack/,
              name: 'react-query',
              priority: 20,
            },
            // Common chunks
            common: {
              minChunks: 2,
              priority: 5,
              reuseExistingChunk: true,
            },
          },
        },
      };
    }
    return config;
  },
  // Image optimization
  images: {
    formats: ['image/avif', 'image/webp'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
    minimumCacheTTL: 60,
    // Allow external images from any domain (for link previews, user content, etc.)
    // This is necessary for a social media app that displays user-generated content
    remotePatterns: [
      {
        protocol: 'https',
        hostname: '**',
      },
      {
        protocol: 'http',
        hostname: '**',
      },
    ],
    // Unoptimized flag for external images that can't be optimized
    unoptimized: false,
  },
  // Turbopack configuration (Next.js 16+ default)
  turbopack: {
    // Turbopack handles tree shaking and optimization automatically
  },
  // Security and performance headers
  headers: async () => [
    {
      source: '/:path*',
      headers: [
        {
          key: 'X-DNS-Prefetch-Control',
          value: 'on'
        },
        {
          key: 'Strict-Transport-Security',
          value: 'max-age=31536000; includeSubDomains; preload'
        },
        {
          key: 'X-Content-Type-Options',
          value: 'nosniff'
        },
        {
          key: 'X-Frame-Options',
          value: 'DENY' // Changed from SAMEORIGIN to DENY for better security
        },
        {
          key: 'X-XSS-Protection',
          value: '1; mode=block'
        },
        {
          key: 'Referrer-Policy',
          value: 'strict-origin-when-cross-origin'
        },
        {
          key: 'Permissions-Policy',
          value: 'camera=(), microphone=(), geolocation=()'
        },
      ],
    },
    // Cache static assets aggressively
    {
      source: '/PWA-icons/:path*',
      headers: [
        {
          key: 'Cache-Control',
          value: 'public, max-age=31536000, immutable',
        },
      ],
    },
    {
      source: '/assets/:path*',
      headers: [
        {
          key: 'Cache-Control',
          value: 'public, max-age=31536000, immutable',
        },
      ],
    },
  ],
  
  // Environment variable validation
  env: {
    NEXT_PUBLIC_API_BASE_URL: process.env.NEXT_PUBLIC_API_BASE_URL || '',
    NEXT_PUBLIC_APP_URL: process.env.NEXT_PUBLIC_APP_URL || '',
  },
};

export default nextConfig;
