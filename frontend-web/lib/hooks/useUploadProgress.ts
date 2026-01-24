'use client';

import { useState, useCallback, useRef } from 'react';

export interface UploadProgress {
  uploadId: string;
  filename: string;
  progress: number; // 0-100
  status: 'uploading' | 'completed' | 'failed' | 'cancelled';
  error?: string;
}

export function useUploadProgress() {
  const [uploads, setUploads] = useState<Map<string, UploadProgress>>(new Map());
  const abortControllers = useRef<Map<string, AbortController>>(new Map());

  const startUpload = useCallback((uploadId: string, filename: string) => {
    const controller = new AbortController();
    abortControllers.current.set(uploadId, controller);

    setUploads(prev => new Map(prev).set(uploadId, {
      uploadId,
      filename,
      progress: 0,
      status: 'uploading',
    }));

    console.log('[UploadProgress] 🚀 Started upload:', uploadId, filename);
    return controller.signal;
  }, []);

  const updateProgress = useCallback((uploadId: string, progress: number) => {
    setUploads(prev => {
      const upload = prev.get(uploadId);
      if (!upload) return prev;

      const updated = new Map(prev);
      updated.set(uploadId, {
        ...upload,
        progress: Math.min(100, Math.max(0, progress)),
      });
      return updated;
    });
  }, []);

  const completeUpload = useCallback((uploadId: string) => {
    setUploads(prev => {
      const upload = prev.get(uploadId);
      if (!upload) return prev;

      const updated = new Map(prev);
      updated.set(uploadId, {
        ...upload,
        progress: 100,
        status: 'completed',
      });
      
      // Remove from map after 2 seconds
      setTimeout(() => {
        setUploads(current => {
          const newMap = new Map(current);
          newMap.delete(uploadId);
          return newMap;
        });
        abortControllers.current.delete(uploadId);
      }, 2000);

      return updated;
    });

    console.log('[UploadProgress] ✅ Completed upload:', uploadId);
  }, []);

  const failUpload = useCallback((uploadId: string, error: string) => {
    setUploads(prev => {
      const upload = prev.get(uploadId);
      if (!upload) return prev;

      const updated = new Map(prev);
      updated.set(uploadId, {
        ...upload,
        status: 'failed',
        error,
      });
      return updated;
    });

    abortControllers.current.delete(uploadId);
    console.error('[UploadProgress] ❌ Failed upload:', uploadId, error);
  }, []);

  const cancelUpload = useCallback((uploadId: string) => {
    const controller = abortControllers.current.get(uploadId);
    if (controller) {
      controller.abort();
      abortControllers.current.delete(uploadId);
    }

    setUploads(prev => {
      const upload = prev.get(uploadId);
      if (!upload) return prev;

      const updated = new Map(prev);
      updated.set(uploadId, {
        ...upload,
        status: 'cancelled',
      });
      
      // Remove after brief delay
      setTimeout(() => {
        setUploads(current => {
          const newMap = new Map(current);
          newMap.delete(uploadId);
          return newMap;
        });
      }, 1000);

      return updated;
    });

    console.log('[UploadProgress] 🚫 Cancelled upload:', uploadId);
  }, []);

  const retryUpload = useCallback((uploadId: string) => {
    setUploads(prev => {
      const upload = prev.get(uploadId);
      if (!upload) return prev;

      const updated = new Map(prev);
      updated.set(uploadId, {
        ...upload,
        progress: 0,
        status: 'uploading',
        error: undefined,
      });
      return updated;
    });

    const controller = new AbortController();
    abortControllers.current.set(uploadId, controller);
    
    console.log('[UploadProgress] 🔄 Retrying upload:', uploadId);
    return controller.signal;
  }, []);

  const getUpload = useCallback((uploadId: string): UploadProgress | undefined => {
    return uploads.get(uploadId);
  }, [uploads]);

  const getActiveUploads = useCallback((): UploadProgress[] => {
    return Array.from(uploads.values()).filter(u => u.status === 'uploading');
  }, [uploads]);

  return {
    startUpload,
    updateProgress,
    completeUpload,
    failUpload,
    cancelUpload,
    retryUpload,
    getUpload,
    getActiveUploads,
    uploads: Array.from(uploads.values()),
  };
}

