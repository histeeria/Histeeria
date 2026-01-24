/**
 * Media Upload API
 * Handles image, video, and audio uploads for posts
 */

const API_BASE = '/api/proxy/v1';

async function uploadFile(
  endpoint: string,
  file: File | Blob,
  onProgress?: (progress: number) => void
): Promise<{ url: string; media_id?: string }> {
  const token = localStorage.getItem('token');
  
  const formData = new FormData();
  formData.append('file', file);

  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();

    xhr.upload.addEventListener('progress', (e) => {
      if (e.lengthComputable && onProgress) {
        const progress = (e.loaded / e.total) * 100;
        onProgress(progress);
      }
    });

    xhr.addEventListener('load', () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          const response = JSON.parse(xhr.responseText);
          resolve(response);
        } catch (error) {
          resolve({ url: xhr.responseText });
        }
      } else {
        try {
          const error = JSON.parse(xhr.responseText);
          reject(new Error(error.message || `Upload failed: ${xhr.status}`));
        } catch {
          reject(new Error(`Upload failed: ${xhr.status}`));
        }
      }
    });

    xhr.addEventListener('error', () => {
      reject(new Error('Network error during upload'));
    });

    xhr.addEventListener('abort', () => {
      reject(new Error('Upload cancelled'));
    });

    xhr.open('POST', `${API_BASE}${endpoint}`);
    
    if (token) {
      xhr.setRequestHeader('Authorization', `Bearer ${token}`);
    }

    xhr.send(formData);
  });
}

export const mediaAPI = {
  /**
   * Upload image
   */
  uploadImage: async (
    file: File,
    onProgress?: (progress: number) => void
  ): Promise<{ url: string; media_id?: string }> => {
    return uploadFile('/posts/upload-image', file, onProgress);
  },

  /**
   * Upload video
   */
  uploadVideo: async (
    file: File | Blob,
    onProgress?: (progress: number) => void
  ): Promise<{ url: string; media_id?: string }> => {
    return uploadFile('/posts/upload-video', file, onProgress);
  },

  /**
   * Upload audio
   */
  uploadAudio: async (
    file: File | Blob,
    onProgress?: (progress: number) => void
  ): Promise<{ url: string; media_id?: string }> => {
    return uploadFile('/posts/upload-audio', file, onProgress);
  },

  /**
   * Upload multiple images
   */
  uploadImages: async (
    files: File[],
    onProgress?: (progress: number) => void
  ): Promise<{ url: string; media_id?: string }[]> => {
    const results = await Promise.all(
      files.map((file, index) => {
        const fileProgress = (progress: number) => {
          if (onProgress) {
            const totalProgress = ((index / files.length) * 100) + (progress / files.length);
            onProgress(totalProgress);
          }
        };
        return mediaAPI.uploadImage(file, fileProgress);
      })
    );
    return results;
  },
};

