'use client';

import { useEffect, useState } from 'react';

export default function ReadingProgress() {
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const updateProgress = () => {
      const windowHeight = window.innerHeight;
      const documentHeight = document.documentElement.scrollHeight;
      const scrollTop = window.scrollY;
      
      const scrollableHeight = documentHeight - windowHeight;
      const scrolled = scrollTop;
      
      const percentage = scrollableHeight > 0 
        ? Math.min((scrolled / scrollableHeight) * 100, 100)
        : 0;
      
      setProgress(percentage);
    };

    window.addEventListener('scroll', updateProgress);
    window.addEventListener('resize', updateProgress);
    updateProgress(); // Initial calculation

    return () => {
      window.removeEventListener('scroll', updateProgress);
      window.removeEventListener('resize', updateProgress);
    };
  }, []);

  return (
    <div className="fixed top-0 left-0 right-0 h-1 bg-neutral-200 dark:bg-neutral-800 z-50">
      <div
        className="h-full bg-gradient-to-r from-purple-600 to-purple-400 transition-all duration-150 ease-out"
        style={{ width: `${progress}%` }}
      />
    </div>
  );
}

