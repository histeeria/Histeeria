'use client';

import { useEffect, useState } from 'react';
import { ChevronRight } from 'lucide-react';

interface Heading {
  id: string;
  text: string;
  level: number;
}

interface TableOfContentsProps {
  contentHtml: string;
}

export default function TableOfContents({ contentHtml }: TableOfContentsProps) {
  const [headings, setHeadings] = useState<Heading[]>([]);
  const [activeId, setActiveId] = useState<string>('');

  useEffect(() => {
    // Parse headings from HTML content
    if (typeof window === 'undefined') return;

    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = contentHtml;
    
    const headingElements = tempDiv.querySelectorAll('h1, h2, h3, h4, h5, h6');
    const parsedHeadings: Heading[] = [];

    headingElements.forEach((heading) => {
      const id = heading.id || heading.textContent?.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '') || '';
      if (!heading.id) {
        heading.id = id;
      }
      
      const level = parseInt(heading.tagName.charAt(1));
      parsedHeadings.push({
        id,
        text: heading.textContent || '',
        level,
      });
    });

    setHeadings(parsedHeadings);

    // Update active heading on scroll
    const handleScroll = () => {
      const scrollPosition = window.scrollY + 100; // Offset for fixed header

      for (let i = headings.length - 1; i >= 0; i--) {
        const element = document.getElementById(headings[i].id);
        if (element && element.offsetTop <= scrollPosition) {
          setActiveId(headings[i].id);
          break;
        }
      }
    };

    window.addEventListener('scroll', handleScroll);
    handleScroll(); // Initial check

    return () => {
      window.removeEventListener('scroll', handleScroll);
    };
  }, [contentHtml, headings.length]);

  if (headings.length === 0) {
    return null;
  }

  const scrollToHeading = (id: string) => {
    const element = document.getElementById(id);
    if (element) {
      const offset = 100; // Account for fixed header
      const elementPosition = element.getBoundingClientRect().top;
      const offsetPosition = elementPosition + window.pageYOffset - offset;

      window.scrollTo({
        top: offsetPosition,
        behavior: 'smooth',
      });
    }
  };

  return (
    <div className="hidden lg:block">
      <div className="sticky top-24 max-h-[calc(100vh-8rem)] overflow-y-auto">
        <div className="bg-neutral-50 dark:bg-neutral-900 rounded-xl p-6 border border-neutral-200 dark:border-neutral-800">
          <h3 className="text-sm font-semibold text-neutral-900 dark:text-neutral-50 mb-4 uppercase tracking-wider">
            Table of Contents
          </h3>
          <nav className="space-y-1">
            {headings.map((heading) => (
              <button
                key={heading.id}
                onClick={() => scrollToHeading(heading.id)}
                className={`block w-full text-left px-3 py-2 rounded-md transition-colors text-sm ${
                  activeId === heading.id
                    ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300 font-medium'
                    : 'text-neutral-600 dark:text-neutral-400 hover:text-neutral-900 dark:hover:text-neutral-200 hover:bg-neutral-100 dark:hover:bg-neutral-800'
                } ${
                  heading.level === 1 ? 'pl-3 font-semibold' :
                  heading.level === 2 ? 'pl-4' :
                  heading.level === 3 ? 'pl-6 text-xs' :
                  'pl-8 text-xs'
                }`}
              >
                <span className="flex items-center gap-2">
                  {heading.level > 2 && (
                    <ChevronRight className="w-3 h-3 opacity-50" />
                  )}
                  <span className="truncate">{heading.text}</span>
                </span>
              </button>
            ))}
          </nav>
        </div>
      </div>
    </div>
  );
}

