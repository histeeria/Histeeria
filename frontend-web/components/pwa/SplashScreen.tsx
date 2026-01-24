'use client';

/**
 * Professional Splash Screen for PWA
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Clean, minimal, professional - appears every launch
 */

import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import Image from 'next/image';

interface SplashScreenProps {
  onComplete: () => void;
}

export default function SplashScreen({ onComplete }: SplashScreenProps) {
  const [show, setShow] = useState(true);

  useEffect(() => {
    // Show splash for 3 seconds - professional branding time
    const timer = setTimeout(() => {
      setShow(false);
      setTimeout(onComplete, 300);
    }, 3000);

    return () => clearTimeout(timer);
  }, [onComplete]);

  return (
    <AnimatePresence>
      {show && (
        <motion.div
          initial={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.3, ease: 'easeOut' }}
          className="fixed inset-0 z-[9999] flex flex-col items-center justify-center"
          style={{
            background: 'linear-gradient(135deg, #7c3aed 0%, #5b21b6 100%)',
          }}
        >
          {/* Logo - Clean entrance */}
          <motion.div
            initial={{ scale: 0.92, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{
              duration: 0.4,
              ease: [0.22, 1, 0.36, 1], // Smooth easeOutCubic
            }}
            className="mb-6"
          >
            <div className="w-24 h-24 md:w-28 md:h-28">
              <Image
                src="/PWA-icons/android/android-launchericon-512-512.png"
                alt="Histeeria"
                width={112}
                height={112}
                className="drop-shadow-2xl"
                priority
              />
            </div>
          </motion.div>

          {/* App Name - Elegant fade */}
          <motion.h1
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.15, duration: 0.35, ease: 'easeOut' }}
            className="text-4xl md:text-5xl font-bold text-white mb-3 tracking-tight"
          >
            Histeeria
          </motion.h1>

          {/* Tagline - Subtle entrance */}
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 0.9 }}
            transition={{ delay: 0.3, duration: 0.35 }}
            className="text-base text-white/90 font-normal tracking-wide mb-16"
          >
            Build a different world
          </motion.p>

          {/* Loading Bar - Minimal and professional */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.5, duration: 0.3 }}
            className="w-16 h-1 bg-white/20 rounded-full overflow-hidden"
          >
            <motion.div
              initial={{ x: '-100%' }}
              animate={{ x: '100%' }}
              transition={{
                duration: 1.2,
                repeat: Infinity,
                ease: 'easeInOut',
              }}
              className="h-full w-1/2 bg-white/80 rounded-full"
            />
          </motion.div>

          {/* Footer - Subtle and professional */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.7, duration: 0.3 }}
            className="absolute bottom-8 text-center"
          >
            <p className="text-xs text-white/50 font-normal tracking-wide">
              Made by <span className="text-white/80 font-medium">Hamza Hafeez</span>
            </p>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

