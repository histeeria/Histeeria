/**
 * useVoiceRecorder - Hook for recording voice messages
 * Uses MediaRecorder API to record audio in WebM/Opus format
 */

import { useState, useRef, useCallback } from 'react';

interface UseVoiceRecorderReturn {
  isRecording: boolean;
  duration: number;
  startRecording: () => Promise<void>;
  stopRecording: () => Promise<Blob | null>;
  cancelRecording: () => void;
  isPaused: boolean;
  pauseRecording: () => void;
  resumeRecording: () => void;
}

export function useVoiceRecorder(): UseVoiceRecorderReturn {
  const [isRecording, setIsRecording] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [duration, setDuration] = useState(0);

  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const streamRef = useRef<MediaStream | null>(null);
  const durationIntervalRef = useRef<NodeJS.Timeout | null>(null);
  const startTimeRef = useRef<number>(0);
  const accumulatedDurationRef = useRef<number>(0); // Changed from pausedDurationRef

  /**
   * Start recording audio
   */
  const startRecording = useCallback(async () => {
    try {
      // Request microphone permission
      const stream = await navigator.mediaDevices.getUserMedia({ 
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        } 
      });

      streamRef.current = stream;

      // Check if WebM/Opus is supported
      const mimeType = MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
        ? 'audio/webm;codecs=opus'
        : 'audio/webm';

      const mediaRecorder = new MediaRecorder(stream, { mimeType });

      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          chunksRef.current.push(event.data);
        }
      };

      mediaRecorder.start();
      mediaRecorderRef.current = mediaRecorder;
      setIsRecording(true);
      setIsPaused(false);

      // Start duration counter
      startTimeRef.current = Date.now();
      accumulatedDurationRef.current = 0;

      durationIntervalRef.current = setInterval(() => {
        const elapsed = Math.floor((Date.now() - startTimeRef.current + accumulatedDurationRef.current) / 1000);
        setDuration(elapsed);
      }, 100); // Update every 100ms for smooth counter

      console.log('[VoiceRecorder] Recording started');
    } catch (error) {
      console.error('[VoiceRecorder] Error starting recording:', error);

      // Handle specific errors
      if (error instanceof Error) {
        const { toast } = await import('@/components/ui/Toast');
        if (error.name === 'NotAllowedError') {
          toast.error('Microphone permission denied. Please allow microphone access.');
        } else if (error.name === 'NotFoundError') {
          toast.error('No microphone found. Please connect a microphone.');
        } else {
          toast.error('Failed to start recording: ' + error.message);
        }
      }

      throw error;
    }
  }, []);

  /**
   * Stop recording and return audio blob
   */
  const stopRecording = useCallback((): Promise<Blob | null> => {
    return new Promise((resolve) => {
      if (!mediaRecorderRef.current || mediaRecorderRef.current.state === 'inactive') {
        resolve(null);
        return;
      }

      mediaRecorderRef.current.onstop = () => {
        // Create blob from chunks
        const blob = new Blob(chunksRef.current, { type: 'audio/webm' });

        // Cleanup
        if (streamRef.current) {
          streamRef.current.getTracks().forEach((track) => track.stop());
          streamRef.current = null;
        }

        if (durationIntervalRef.current) {
          clearInterval(durationIntervalRef.current);
          durationIntervalRef.current = null;
        }

        chunksRef.current = [];
        mediaRecorderRef.current = null;
        setIsRecording(false);
        setIsPaused(false);
        setDuration(0);

        console.log('[VoiceRecorder] Recording stopped, blob size:', blob.size);
        resolve(blob);
      };

      mediaRecorderRef.current.stop();
    });
  }, []);

  /**
   * Cancel recording without saving
   */
  const cancelRecording = useCallback(() => {
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      mediaRecorderRef.current.stop();
    }

    // Cleanup
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((track) => track.stop());
      streamRef.current = null;
    }

    if (durationIntervalRef.current) {
      clearInterval(durationIntervalRef.current);
      durationIntervalRef.current = null;
    }

    chunksRef.current = [];
    mediaRecorderRef.current = null;
    setIsRecording(false);
    setIsPaused(false);
    setDuration(0);

    console.log('[VoiceRecorder] Recording cancelled');
  }, []);

  /**
   * Pause recording
   */
  const pauseRecording = useCallback(() => {
    if (mediaRecorderRef.current && mediaRecorderRef.current.state === 'recording') {
      mediaRecorderRef.current.pause();
      setIsPaused(true);

      // Save the current duration before pausing
      accumulatedDurationRef.current += Date.now() - startTimeRef.current;

      console.log('[VoiceRecorder] Recording paused, accumulated duration:', accumulatedDurationRef.current);
    }
  }, []);

  /**
   * Resume recording
   */
  const resumeRecording = useCallback(() => {
    if (mediaRecorderRef.current && mediaRecorderRef.current.state === 'paused') {
      mediaRecorderRef.current.resume();
      setIsPaused(false);

      // Reset start time to now, keeping accumulated duration
      startTimeRef.current = Date.now();

      console.log('[VoiceRecorder] Recording resumed from:', accumulatedDurationRef.current);
    }
  }, []);

  return {
    isRecording,
    duration,
    startRecording,
    stopRecording,
    cancelRecording,
    isPaused,
    pauseRecording,
    resumeRecording,
  };
}

