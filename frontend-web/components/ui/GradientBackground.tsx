'use client';

/**
 * Gradient Background Component
 * Created by: Hamza Hafeez - Founder & CEO of Asteria
 * 
 * Animated gradient mist background inspired by Flutter gradient_background.dart
 * Creates a beautiful, subtle animated gradient mist effect
 */

import { useEffect, useState } from 'react';

interface GradientBackgroundProps {
  children: React.ReactNode;
  className?: string;
}

export function GradientBackground({ children, className = '' }: GradientBackgroundProps) {
  const [animationProgress, setAnimationProgress] = useState(0);

  useEffect(() => {
    // Animate gradient mist smoothly
    const duration = 8000; // 8 seconds for smooth transition
    let startTime: number | null = null;
    let animationFrame: number;

    const animate = (timestamp: number) => {
      if (!startTime) startTime = timestamp;
      const elapsed = timestamp - startTime;
      const progress = (elapsed % duration) / duration;
      setAnimationProgress(progress);
      animationFrame = requestAnimationFrame(animate);
    };

    animationFrame = requestAnimationFrame(animate);

    return () => {
      cancelAnimationFrame(animationFrame);
    };
  }, []);

  // Calculate color transitions using sine waves (similar to Flutter implementation)
  const t = animationProgress;
  const sin = Math.sin;
  const cos = Math.cos;
  const PI = Math.PI;

  // Base colors from app_colors.dart
  const purple = { r: 155, g: 89, b: 182 }; // #9B59B6
  const pink = { r: 233, g: 69, b: 96 };    // #E94560
  const blue = { r: 74, g: 144, b: 226 };    // #4A90E2

  // Interpolate colors smoothly
  const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
  const colorLerp = (c1: typeof purple, c2: typeof purple, t: number) => ({
    r: Math.round(lerp(c1.r, c2.r, t)),
    g: Math.round(lerp(c1.g, c2.g, t)),
    b: Math.round(lerp(c1.b, c2.b, t)),
  });

  const color1 = colorLerp(purple, pink, (sin(t * 2 * PI) + 1) / 2);
  const color2 = colorLerp(pink, blue, (sin(t * 2 * PI + PI / 3) + 1) / 2);
  const color3 = colorLerp(blue, purple, (sin(t * 2 * PI + 2 * PI / 3) + 1) / 2);

  const color1Str = `rgb(${color1.r}, ${color1.g}, ${color1.b})`;
  const color2Str = `rgb(${color2.r}, ${color2.g}, ${color2.b})`;
  const color3Str = `rgb(${color3.r}, ${color3.g}, ${color3.b})`;

  // Calculate mist positions (animated)
  const mist1X = -100 + sin(t * 2 * PI) * 50;
  const mist1Y = -100 + cos(t * 2 * PI) * 50;
  const mist2X = -100 + cos(t * 2 * PI + PI / 3) * 50;
  const mist2Y = -100 + sin(t * 2 * PI + PI / 3) * 50;
  const mist3Y = -150 + sin(t * 2 * PI + 2 * PI / 3) * 60;
  const mist4Size = 300 + sin(t * 2 * PI) * 30;

  return (
    <div className={`fixed inset-0 overflow-hidden ${className}`} style={{ zIndex: 0 }}>
      {/* Base dark background */}
      <div className="absolute inset-0 bg-[#0A0A0A]" />
      
      {/* Animated gradient mists */}
      <div className="absolute inset-0">
        {/* Mist 1 - Top left */}
        <div
          className="absolute rounded-full"
          style={{
            left: `${mist1X}px`,
            top: `${mist1Y}px`,
            width: '400px',
            height: '400px',
            background: `radial-gradient(circle, ${color1Str}25 0%, ${color1Str}15 30%, ${color1Str}05 60%, transparent 100%)`,
            filter: 'blur(100px)',
          }}
        />
        
        {/* Mist 2 - Top right */}
        <div
          className="absolute rounded-full"
          style={{
            right: `${mist2X}px`,
            top: `${mist2Y}px`,
            width: '450px',
            height: '450px',
            background: `radial-gradient(circle, ${color2Str}25 0%, ${color2Str}15 30%, ${color2Str}05 60%, transparent 100%)`,
            filter: 'blur(100px)',
          }}
        />
        
        {/* Mist 3 - Bottom center */}
        <div
          className="absolute rounded-full left-1/2 -translate-x-1/2"
          style={{
            bottom: `${mist3Y}px`,
            width: '500px',
            height: '500px',
            background: `radial-gradient(circle, ${color3Str}25 0%, ${color3Str}15 30%, ${color3Str}05 60%, transparent 100%)`,
            filter: 'blur(100px)',
          }}
        />
        
        {/* Mist 4 - Center (subtle) */}
        <div
          className="absolute rounded-full left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
          style={{
            width: `${mist4Size}px`,
            height: `${mist4Size}px`,
            background: `radial-gradient(circle, ${color1Str}18 0%, ${color2Str}12 50%, transparent 100%)`,
            filter: 'blur(100px)',
          }}
        />
      </div>
      
      {/* Content */}
      <div className="relative z-10">
        {children}
      </div>
    </div>
  );
}
