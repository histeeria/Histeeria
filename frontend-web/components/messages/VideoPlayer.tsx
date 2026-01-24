'use client';

import { useState, useRef, useEffect } from 'react';
import { Play, Pause, Maximize2, Volume2, VolumeX } from 'lucide-react';

// Global video instance tracker to ensure only one plays at a time
let currentlyPlayingVideo: HTMLVideoElement | null = null;

interface VideoPlayerProps {
  url: string;
  thumbnailUrl?: string;
  duration?: number;
  width?: number;
  height?: number;
  onExpand?: () => void;
}

export default function VideoPlayer({ 
  url, 
  thumbnailUrl,
  duration: initialDuration = 0,
  width,
  height,
  onExpand 
}: VideoPlayerProps) {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(initialDuration);
  const [playbackRate, setPlaybackRate] = useState(1);
  const [isMuted, setIsMuted] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [showControls, setShowControls] = useState(true);

  const videoRef = useRef<HTMLVideoElement>(null);
  const progressRef = useRef<HTMLDivElement>(null);
  const controlsTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  // ==================== PLAYBACK SPEEDS ====================

  const speeds = [0.5, 1, 1.5, 2];

  const cycleSpeed = () => {
    const currentIndex = speeds.indexOf(playbackRate);
    const nextIndex = (currentIndex + 1) % speeds.length;
    const newSpeed = speeds[nextIndex];
    
    if (videoRef.current) {
      videoRef.current.playbackRate = newSpeed;
    }
    setPlaybackRate(newSpeed);
    console.log('[VideoPlayer] Playback speed changed to:', newSpeed + 'x');
  };

  // ==================== PLAYBACK CONTROLS ====================

  const togglePlayPause = async () => {
    if (!videoRef.current) return;

    try {
      if (isPlaying) {
        // PAUSE
        console.log('[VideoPlayer] PAUSING video:', url);
        videoRef.current.pause();
        setIsPlaying(false);
        
        // Clear global reference
        if (currentlyPlayingVideo === videoRef.current) {
          currentlyPlayingVideo = null;
        }
      } else {
        // PLAY - Pause any other playing video/audio
        if (currentlyPlayingVideo && currentlyPlayingVideo !== videoRef.current) {
          console.log('[VideoPlayer] Pausing other video to play this one');
          currentlyPlayingVideo.pause();
          currentlyPlayingVideo = null;
        }
        
        // Also pause any playing audio
        const currentlyPlayingAudio = (window as any).currentlyPlayingAudio;
        if (currentlyPlayingAudio && currentlyPlayingAudio !== videoRef.current) {
          console.log('[VideoPlayer] Pausing audio to play video');
          currentlyPlayingAudio.pause();
        }
        
        console.log('[VideoPlayer] PLAYING video:', url);
        setIsLoading(true);
        await videoRef.current.play();
        setIsPlaying(true);
        setIsLoading(false);
        
        // Set this as the currently playing video
        currentlyPlayingVideo = videoRef.current;
      }
    } catch (error) {
      console.error('[VideoPlayer] Playback error:', error);
      setIsLoading(false);
      setIsPlaying(false);
      
      if (currentlyPlayingVideo === videoRef.current) {
        currentlyPlayingVideo = null;
      }
    }
  };

  const toggleMute = () => {
    if (videoRef.current) {
      videoRef.current.muted = !isMuted;
      setIsMuted(!isMuted);
    }
  };

  const handleSeek = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!videoRef.current || !progressRef.current) return;

    const rect = progressRef.current.getBoundingClientRect();
    const percent = (e.clientX - rect.left) / rect.width;
    const seekTime = percent * duration;

    videoRef.current.currentTime = seekTime;
    setCurrentTime(seekTime);
  };

  // ==================== CONTROLS VISIBILITY ====================

  const showControlsTemporarily = () => {
    setShowControls(true);
    
    if (controlsTimeoutRef.current) {
      clearTimeout(controlsTimeoutRef.current);
    }
    
    controlsTimeoutRef.current = setTimeout(() => {
      if (isPlaying) {
        setShowControls(false);
      }
    }, 3000);
  };

  const handleMouseMove = () => {
    showControlsTemporarily();
  };

  // ==================== VIDEO EVENT LISTENERS ====================

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    const handleTimeUpdate = () => {
      setCurrentTime(video.currentTime);
    };

    const handleDurationChange = () => {
      setDuration(video.duration);
    };

    const handleEnded = () => {
      console.log('[VideoPlayer] Video ended');
      setIsPlaying(false);
      setCurrentTime(0);
      video.currentTime = 0;
      setShowControls(true);
      
      if (currentlyPlayingVideo === video) {
        currentlyPlayingVideo = null;
      }
    };

    const handlePause = () => {
      console.log('[VideoPlayer] Video paused event');
      setIsPlaying(false);
      setShowControls(true);
      
      if (currentlyPlayingVideo === video) {
        currentlyPlayingVideo = null;
      }
    };

    const handlePlay = () => {
      console.log('[VideoPlayer] Video playing event');
      setIsPlaying(true);
    };

    const handleLoadStart = () => {
      setIsLoading(true);
    };

    const handleCanPlay = () => {
      setIsLoading(false);
    };

    const handleError = () => {
      if (video.error) {
        const errorMessages: Record<number, string> = {
          1: 'Video loading aborted',
          2: 'Network error while loading video',
          3: 'Video decoding failed',
          4: 'Video format not supported or file not found',
        };
        const errorMsg = errorMessages[video.error.code] || `Unknown error (${video.error.code})`;
        console.error('[VideoPlayer] Video error:', errorMsg, 'URL:', url);
      }
      setIsLoading(false);
      setIsPlaying(false);
      
      if (currentlyPlayingVideo === video) {
        currentlyPlayingVideo = null;
      }
    };

    video.addEventListener('timeupdate', handleTimeUpdate);
    video.addEventListener('durationchange', handleDurationChange);
    video.addEventListener('ended', handleEnded);
    video.addEventListener('pause', handlePause);
    video.addEventListener('play', handlePlay);
    video.addEventListener('loadstart', handleLoadStart);
    video.addEventListener('canplay', handleCanPlay);
    video.addEventListener('error', handleError);

    // Cleanup on unmount
    return () => {
      console.log('[VideoPlayer] Component unmounting, cleaning up');
      
      if (video.paused === false) {
        video.pause();
      }
      
      if (currentlyPlayingVideo === video) {
        currentlyPlayingVideo = null;
      }
      
      video.removeEventListener('timeupdate', handleTimeUpdate);
      video.removeEventListener('durationchange', handleDurationChange);
      video.removeEventListener('ended', handleEnded);
      video.removeEventListener('pause', handlePause);
      video.removeEventListener('play', handlePlay);
      video.removeEventListener('loadstart', handleLoadStart);
      video.removeEventListener('canplay', handleCanPlay);
      video.removeEventListener('error', handleError as any);
    };
  }, [url]);

  // Set playback rate when speed changes
  useEffect(() => {
    if (videoRef.current) {
      videoRef.current.playbackRate = playbackRate;
    }
  }, [playbackRate]);

  // ==================== HELPERS ====================

  const formatTime = (seconds: number): string => {
    if (!isFinite(seconds)) return '0:00';
    
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const getProgress = (): number => {
    if (!duration || !isFinite(duration)) return 0;
    return (currentTime / duration) * 100;
  };

  // ==================== RENDER ====================

  return (
    <div 
      className="relative w-full bg-black rounded-lg overflow-hidden group cursor-pointer"
      onMouseMove={handleMouseMove}
      onMouseEnter={() => setShowControls(true)}
      onMouseLeave={() => {
        if (!isPlaying) setShowControls(true);
        else showControlsTemporarily();
      }}
      onClick={(e) => {
        // Click on video (not controls) to expand
        if ((e.target as HTMLElement).tagName === 'VIDEO') {
          onExpand?.();
        }
      }}
    >
      {/* Video Element */}
      <video
        ref={videoRef}
        src={url}
        poster={thumbnailUrl}
        preload="metadata"
        className="w-full h-auto max-h-[400px] object-contain"
        playsInline
        muted={isMuted}
      />

      {/* Loading Overlay */}
      {isLoading && (
        <div className="absolute inset-0 flex items-center justify-center bg-black/50">
          <div className="w-12 h-12 border-4 border-white border-t-transparent rounded-full animate-spin" />
        </div>
      )}

      {/* Play Button Overlay (when paused) */}
      {!isPlaying && !isLoading && (
        <div className="absolute inset-0 flex items-center justify-center bg-black/30">
          <button
            onClick={togglePlayPause}
            className="w-16 h-16 bg-white/90 hover:bg-white rounded-full flex items-center justify-center transition-all transform hover:scale-110 shadow-2xl"
          >
            <Play className="w-8 h-8 text-gray-900 ml-1" fill="currentColor" />
          </button>
        </div>
      )}

      {/* Controls Overlay */}
      <div
        className={`absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/80 via-black/50 to-transparent p-3 transition-opacity duration-300 ${
          showControls || !isPlaying ? 'opacity-100' : 'opacity-0'
        }`}
      >
        {/* Progress Bar - Instagram Style */}
        <div className="mb-3 group/progress">
          <div
            ref={progressRef}
            onClick={handleSeek}
            className="h-[3px] bg-white/20 rounded-full cursor-pointer relative overflow-visible hover:h-[4px] transition-all duration-200"
          >
            {/* Filled Progress */}
            <div
              className="h-full bg-gradient-to-r from-white to-white/90 rounded-full transition-all duration-150 relative"
              style={{ width: `${getProgress()}%` }}
            >
              {/* Progress Thumb */}
              {isPlaying && getProgress() > 0 && (
                <div className="absolute right-0 top-1/2 -translate-y-1/2 w-2.5 h-2.5 bg-white rounded-full shadow-lg scale-0 group-hover/progress:scale-100 transition-transform duration-200" />
              )}
            </div>
          </div>
        </div>

        {/* Control Buttons */}
        <div className="flex items-center justify-between gap-2">
          {/* Left: Play/Pause + Time */}
          <div className="flex items-center gap-3">
            <button
              onClick={togglePlayPause}
              className="p-1.5 hover:bg-white/20 rounded-full transition-colors"
              title={isPlaying ? 'Pause' : 'Play'}
            >
              {isPlaying ? (
                <Pause className="w-5 h-5 text-white" />
              ) : (
                <Play className="w-5 h-5 text-white ml-0.5" fill="currentColor" />
              )}
            </button>

            <span className="text-white text-xs font-medium">
              {formatTime(currentTime)} / {formatTime(duration)}
            </span>
          </div>

          {/* Right: Speed + Volume + Fullscreen */}
          <div className="flex items-center gap-2">
            {/* Playback Speed */}
            <button
              onClick={cycleSpeed}
              className="min-w-[40px] h-[24px] px-2 flex items-center justify-center bg-white/10 hover:bg-white/20 rounded-full transition-all duration-150 font-bold text-[10px] text-white border border-white/20 hover:scale-105"
              title="Playback speed"
            >
              {playbackRate}×
            </button>

            {/* Mute/Unmute */}
            <button
              onClick={toggleMute}
              className="p-1.5 hover:bg-white/20 rounded-full transition-colors"
              title={isMuted ? 'Unmute' : 'Mute'}
            >
              {isMuted ? (
                <VolumeX className="w-4 h-4 text-white" />
              ) : (
                <Volume2 className="w-4 h-4 text-white" />
              )}
            </button>

            {/* Fullscreen/Expand */}
            {onExpand && (
              <button
                onClick={onExpand}
                className="p-1.5 hover:bg-white/20 rounded-full transition-colors"
                title="Expand"
              >
                <Maximize2 className="w-4 h-4 text-white" />
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Duration Badge (top-right when paused) */}
      {!isPlaying && duration > 0 && (
        <div className="absolute top-2 right-2 bg-black/70 backdrop-blur-sm px-2 py-1 rounded text-white text-xs font-medium">
          {formatTime(duration)}
        </div>
      )}
    </div>
  );
}

