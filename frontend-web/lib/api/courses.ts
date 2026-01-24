/**
 * Courses API (Stub)
 * Placeholder for future courses/learning platform features
 */

const API_BASE = '/api/proxy/v1';

async function fetchAPI(endpoint: string, options: RequestInit = {}) {
  const token = localStorage.getItem('token');
  
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  
  try {
    const response = await fetch(`${API_BASE}${endpoint}`, {
      ...options,
      headers,
    });
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({ message: 'Request failed' }));
      const message = error.message || error.error || `HTTP ${response.status}`;
      throw new Error(message);
    }
    
    return response.json();
  } catch (error) {
    console.error(`[coursesAPI] Error:`, error);
    throw error;
  }
}

// Types (stub)
export interface Course {
  id: string;
  title: string;
  description?: string;
  cover_image_url?: string;
  creator?: {
    id: string;
    username: string;
    display_name?: string;
    profile_picture?: string;
    is_verified?: boolean;
  };
  difficulty_level: 'beginner' | 'intermediate' | 'advanced' | 'expert';
  estimated_duration?: number; // minutes
  total_lessons: number;
  is_free: boolean;
  price?: number;
  enrollment_count: number;
  average_rating: number;
  created_at: string;
}

export interface LearningMaterial {
  id: string;
  title: string;
  description?: string;
  cover_image_url?: string;
  material_type: 'video' | 'ebook' | 'document' | 'article';
  category?: string;
  is_free: boolean;
  price?: number;
  view_count: number;
  download_count: number;
  created_at: string;
}

export interface GetCoursesParams {
  search?: string;
  sort_by?: 'newest' | 'popular' | 'rating' | 'price_asc' | 'price_desc';
  limit?: number;
  offset?: number;
}

export interface GetMaterialsParams {
  search?: string;
  sort_by?: 'newest' | 'popular' | 'rating' | 'price_asc' | 'price_desc';
  limit?: number;
  offset?: number;
}

export const coursesAPI = {
  /**
   * Get courses (stub - returns empty for now)
   */
  async getCourses(params: GetCoursesParams = {}) {
    // TODO: Implement when courses feature is added
    return {
      success: true,
      courses: [] as Course[],
      total: 0,
    };
  },

  /**
   * Get learning materials (stub - returns empty for now)
   */
  async getMaterials(params: GetMaterialsParams = {}) {
    // TODO: Implement when materials feature is added
    return {
      success: true,
      materials: [] as LearningMaterial[],
      total: 0,
    };
  },
};
