'use client';

/**
 * Theme Context Provider
 * Created by: Hamza Hafeez - Founder & CEO of Asteria
 * 
 * Manages theme switching across the application
 * Asteria theme is the default - dark theme with animated gradient mist
 * Persists user preference in localStorage
 */

import { createContext, useContext, useEffect, useState, ReactNode } from 'react';

type Theme = 'light' | 'dark' | 'ios' | 'asteria';

interface ThemeContextType {
  theme: Theme;
  setTheme: (theme: Theme) => void;
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setTheme] = useState<Theme>('asteria'); // Default to Asteria
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
    // Load theme from localStorage or default to Asteria
    const stored = localStorage.getItem('asteria-theme') as Theme;
    if (stored && (stored === 'light' || stored === 'dark' || stored === 'ios' || stored === 'asteria')) {
      setTheme(stored);
      document.documentElement.classList.remove('dark', 'ios', 'asteria');
      if (stored === 'dark') {
        document.documentElement.classList.add('dark');
      } else if (stored === 'ios') {
        document.documentElement.classList.add('ios');
      } else if (stored === 'asteria') {
        document.documentElement.classList.add('asteria');
      }
    } else {
      // Default to Asteria theme
      setTheme('asteria');
      document.documentElement.classList.add('asteria');
      localStorage.setItem('asteria-theme', 'asteria');
    }
  }, []);

  const handleSetTheme = (newTheme: Theme) => {
    setTheme(newTheme);
    localStorage.setItem('asteria-theme', newTheme);
    
    // Remove all theme classes first
    document.documentElement.classList.remove('dark', 'ios', 'asteria');
    
    // Add appropriate theme class
    if (newTheme === 'dark') {
      document.documentElement.classList.add('dark');
    } else if (newTheme === 'ios') {
      document.documentElement.classList.add('ios');
    } else if (newTheme === 'asteria') {
      document.documentElement.classList.add('asteria');
    }
  };

  const toggleTheme = () => {
    // Cycle through: asteria → light → ios → dark → asteria
    const themeOrder: Theme[] = ['asteria', 'light', 'ios', 'dark'];
    const currentIndex = themeOrder.indexOf(theme);
    const nextIndex = (currentIndex + 1) % themeOrder.length;
    handleSetTheme(themeOrder[nextIndex]);
  };

  // Prevent flash of wrong theme
  if (!mounted) {
    return <div className="min-h-screen bg-[#0A0A0A]" />;
  }

  return (
    <ThemeContext.Provider value={{ theme, setTheme: handleSetTheme, toggleTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within ThemeProvider');
  }
  return context;
};
