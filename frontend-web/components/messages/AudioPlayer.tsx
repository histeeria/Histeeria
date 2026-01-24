'use client';

import { useState, useRef, useEffect } from 'react';
import { Play, Pause } from 'lucide-react';

// Global audio instance tracker to ensure only one plays at a time
let currentlyPlayingAudio: HTMLAudioElement | null = null;

interface AudioPlayerProps {
  url: string;
  duration?: number;
}

export default function AudioPlayer({ url, duration: initialDuration = 0 }: AudioPlayerProps) {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(initialDuration);
  const [playbackRate, setPlaybackRate] = useState(1);
  const [isLoading, setIsLoading] = useState(false);

  const audioRef = useRef<HTMLAudioElement>(null);
  const progressRef = useRef<HTMLDivElement>(null);

  // ==================== PLAYBACK SPEEDS ====================

  const speeds = [1, 1.5, 2];

  const cycleSpeed = () => {
    const currentIndex = speeds.indexOf(playbackRate);
    const nextIndex = (currentIndex + 1) % speeds.length;
    const newSpeed = speeds[nextIndex];
    
    if (audioRef.current) {
      audioRef.current.playbackRate = newSpeed;
    }
    setPlaybackRate(newSpeed);
    console.log('[AudioPlayer] Playback speed changed to:', newSpeed + 'x');
  };

  // ==================== PLAYBACK CONTROLS ====================

  const togglePlayPause = async () => {
    if (!audioRef.current) return;

    try {
      if (isPlaying) {
        // PAUSE - Must actually pause the audio!
        console.log('[AudioPlayer] PAUSING audio:', url);
        audioRef.current.pause();
        setIsPlaying(false);
        
        // Clear global reference if this was the playing audio
        if (currentlyPlayingAudio === audioRef.current) {
          currentlyPlayingAudio = null;
        }
      } else {
        // PLAY - First pause any other playing audio
        if (currentlyPlayingAudio && currentlyPlayingAudio !== audioRef.current) {
          console.log('[AudioPlayer] Pausing other audio to play this one');
          currentlyPlayingAudio.pause();
          currentlyPlayingAudio = null;
        }
        
        console.log('[AudioPlayer] PLAYING audio:', url);
        setIsLoading(true);
        await audioRef.current.play();
        setIsPlaying(true);
        setIsLoading(false);
        
        // Set this as the currently playing audio
        currentlyPlayingAudio = audioRef.current;
      }
    } catch (error) {
      console.error('[AudioPlayer] Playback error:', error);
      setIsLoading(false);
      setIsPlaying(false);
      
      // Clear global reference on error
      if (currentlyPlayingAudio === audioRef.current) {
        currentlyPlayingAudio = null;
      }
    }
  };

  const handleSeek = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!audioRef.current || !progressRef.current) return;

    const rect = progressRef.current.getBoundingClientRect();
    const percent = (e.clientX - rect.left) / rect.width;
    const seekTime = percent * duration;

    audioRef.current.currentTime = seekTime;
    setCurrentTime(seekTime);
  };

  // ==================== AUDIO EVENT LISTENERS ====================

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;

    const handleTimeUpdate = () => {
      setCurrentTime(audio.currentTime);
    };

    const handleDurationChange = () => {
      setDuration(audio.duration);
    };

    const handleEnded = () => {
      console.log('[AudioPlayer] Audio ended');
      setIsPlaying(false);
      setCurrentTime(0);
      audio.currentTime = 0;
      
      // Clear global reference
      if (currentlyPlayingAudio === audio) {
        currentlyPlayingAudio = null;
      }
    };

    const handlePause = () => {
      console.log('[AudioPlayer] Audio paused event');
      setIsPlaying(false);
      
      // Clear global reference if this was the playing audio
      if (currentlyPlayingAudio === audio) {
        currentlyPlayingAudio = null;
      }
    };

    const handlePlay = () => {
      console.log('[AudioPlayer] Audio playing event');
      setIsPlaying(true);
    };

    const handleLoadStart = () => {
      setIsLoading(true);
    };

    const handleCanPlay = () => {
      setIsLoading(false);
    };

    const handleError = () => {
      const audio = audioRef.current;
      if (audio && audio.error) {
        const errorMessages: Record<number, string> = {
          1: 'Audio loading aborted',
          2: 'Network error while loading audio',
          3: 'Audio decoding failed',
          4: 'Audio format not supported or file not found',
        };
        const errorMsg = errorMessages[audio.error.code] || `Unknown error (${audio.error.code})`;
        console.error('[AudioPlayer] Audio error:', errorMsg, 'URL:', url);
      } else {
        console.error('[AudioPlayer] Audio error: Unknown error, URL:', url);
      }
      setIsLoading(false);
      setIsPlaying(false);
      
      // Clear global reference
      if (currentlyPlayingAudio === audio) {
        currentlyPlayingAudio = null;
      }
    };

    audio.addEventListener('timeupdate', handleTimeUpdate);
    audio.addEventListener('durationchange', handleDurationChange);
    audio.addEventListener('ended', handleEnded);
    audio.addEventListener('pause', handlePause);
    audio.addEventListener('play', handlePlay);
    audio.addEventListener('loadstart', handleLoadStart);
    audio.addEventListener('canplay', handleCanPlay);
    audio.addEventListener('error', handleError);

    // Cleanup on unmount
    return () => {
      console.log('[AudioPlayer] Component unmounting, cleaning up');
      
      // Pause audio if playing
      if (audio.paused === false) {
        audio.pause();
      }
      
      // Clear global reference if this was the playing audio
      if (currentlyPlayingAudio === audio) {
        currentlyPlayingAudio = null;
      }
      
      audio.removeEventListener('timeupdate', handleTimeUpdate);
      audio.removeEventListener('durationchange', handleDurationChange);
      audio.removeEventListener('ended', handleEnded);
      audio.removeEventListener('pause', handlePause);
      audio.removeEventListener('play', handlePlay);
      audio.removeEventListener('loadstart', handleLoadStart);
      audio.removeEventListener('canplay', handleCanPlay);
      audio.removeEventListener('error', handleError as any);
    };
  }, [url]);

  // Set playback rate when speed changes
  useEffect(() => {
    if (audioRef.current) {
      audioRef.current.playbackRate = playbackRate;
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
    <div className="w-full max-w-full">
      {/* Hidden Audio Element */}
      <audio
        ref={audioRef}
        src={url}
        preload="metadata"
        className="hidden"
      />

      {/* Audio Controls - Flexible Layout */}
      <div className="flex items-center gap-2 py-2 w-full min-w-[260px]">
        {/* Play/Pause Button */}
        <button
          onClick={togglePlayPause}
          disabled={isLoading}
          className="p-2 bg-white/20 hover:bg-white/30 dark:bg-black/20 dark:hover:bg-black/30 rounded-full transition-colors flex-shrink-0"
          title={isPlaying ? 'Pause' : 'Play'}
        >
          {isLoading ? (
            <div className="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
          ) : isPlaying ? (
            <Pause className="w-4 h-4" />
          ) : (
            <Play className="w-4 h-4 ml-0.5" />
          )}
        </button>

        {/* Waveform & Progress - Takes remaining space */}
        <div className="flex-1 min-w-0">
          {/* Progress Bar Container - Instagram Style */}
          <div className="relative mb-1.5 group">
            {/* Background Track */}
            <div
              ref={progressRef}
              onClick={handleSeek}
              className="h-[3px] bg-white/15 dark:bg-black/15 rounded-full cursor-pointer relative overflow-visible hover:h-[4px] transition-all duration-200"
            >
              {/* Filled Progress with Gradient */}
              <div
                className="h-full bg-gradient-to-r from-white/90 to-white dark:from-purple-400 dark:to-purple-300 rounded-full transition-all duration-150 relative shadow-sm"
                style={{ width: `${getProgress()}%` }}
              >
                {/* Progress Thumb - Instagram Style */}
                {isPlaying && getProgress() > 0 && (
                  <div className="absolute right-0 top-1/2 -translate-y-1/2 w-2 h-2 bg-white dark:bg-purple-400 rounded-full shadow-md scale-0 group-hover:scale-100 transition-transform duration-200" />
                )}
              </div>
            </div>
          </div>

          {/* Time Display */}
          <div className="flex items-center justify-between text-[10px]">
            <span className="opacity-75 truncate font-medium">
              {formatTime(currentTime)} / {formatTime(duration)}
            </span>
          </div>
        </div>

        {/* Playback Speed Button - WhatsApp Style */}
        <button
          onClick={cycleSpeed}
          className="min-w-[44px] h-[28px] px-3 flex items-center justify-center bg-white/10 hover:bg-white/20 active:bg-white/30 dark:bg-black/10 dark:hover:bg-black/20 dark:active:bg-black/30 rounded-full transition-all duration-150 font-bold text-[11px] flex-shrink-0 border border-white/20 dark:border-black/20 hover:scale-105 active:scale-95"
          title="Playback speed (tap to cycle)"
        >
          {playbackRate}×
        </button>
      </div>
    </div>
  );
}
