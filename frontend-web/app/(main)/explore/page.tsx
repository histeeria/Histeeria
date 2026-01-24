'use client';

/**
 * Explore Page - Learning Platform
 * Created by: Hamza Hafeez - Founder & CEO of Asteria
 * 
 * Browse courses, learning materials, and educational content
 * Anyone can create, collaborate, distribute, and benefit from learning resources
 */

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { MainLayout } from '@/components/layout/MainLayout';
import { Button } from '@/components/ui/Button';
import { 
  BookOpen, 
  Plus, 
  Play, 
  Users, 
  Star, 
  Clock, 
  TrendingUp,
  FileText,
  Video,
  Download,
  Search,
  Filter
} from 'lucide-react';
import { coursesAPI, Course, LearningMaterial } from '@/lib/api/courses';
import { Avatar } from '@/components/ui/Avatar';
import { toast } from '@/components/ui/Toast';
import VerifiedBadge from '@/components/ui/VerifiedBadge';

type TabType = 'courses' | 'materials';
type SortType = 'newest' | 'popular' | 'rating' | 'price_asc' | 'price_desc';

export default function ExplorePage() {
  const router = useRouter();
  const [activeTab, setActiveTab] = useState<TabType>('courses');
  const [sortBy, setSortBy] = useState<SortType>('popular');
  const [searchQuery, setSearchQuery] = useState('');
  const [courses, setCourses] = useState<Course[]>([]);
  const [materials, setMaterials] = useState<LearningMaterial[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Load courses
  const loadCourses = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await coursesAPI.getCourses({
        search: searchQuery || undefined,
        sort_by: sortBy,
        limit: 20,
        offset: 0,
      });
      
      if (response.success) {
        setCourses(response.courses || []);
      } else {
        setError('Failed to load courses');
      }
    } catch (err: any) {
      setError(err.message || 'Failed to load courses');
      toast.error(err.message || 'Failed to load courses');
    } finally {
      setLoading(false);
    }
  };

  // Load materials
  const loadMaterials = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await coursesAPI.getMaterials({
        search: searchQuery || undefined,
        sort_by: sortBy,
        limit: 20,
        offset: 0,
      });
      
      if (response.success) {
        setMaterials(response.materials || []);
      } else {
        setError('Failed to load materials');
      }
    } catch (err: any) {
      setError(err.message || 'Failed to load materials');
      toast.error(err.message || 'Failed to load materials');
    } finally {
      setLoading(false);
    }
  };

  // Load data when tab, sort, or search changes
  useEffect(() => {
    if (activeTab === 'courses') {
      loadCourses();
    } else {
      loadMaterials();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeTab, sortBy, searchQuery]);

  const handleCreateCourse = () => {
    router.push('/explore/create-course');
  };

  const handleCourseClick = (courseId: string) => {
    router.push(`/explore/courses/${courseId}`);
  };

  const handleMaterialClick = (materialId: string) => {
    router.push(`/explore/materials/${materialId}`);
  };

  const formatDuration = (minutes?: number) => {
    if (!minutes) return 'N/A';
    if (minutes < 60) return `${minutes}m`;
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    return mins > 0 ? `${hours}h ${mins}m` : `${hours}h`;
  };

  const getDifficultyColor = (level: string) => {
    switch (level) {
      case 'beginner': return 'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400';
      case 'intermediate': return 'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-400';
      case 'advanced': return 'bg-orange-100 dark:bg-orange-900/30 text-orange-700 dark:text-orange-400';
      case 'expert': return 'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400';
      default: return 'bg-neutral-100 dark:bg-neutral-800 text-neutral-700 dark:text-neutral-300';
    }
  };

  return (
    <MainLayout>
      <div className="min-h-screen">
        <div className="w-full max-w-4xl mx-auto px-4 py-4 sm:py-6 md:py-8">
          {/* Header */}
          <div className="mb-6 sm:mb-8">
            <div className="flex items-start justify-between gap-3 mb-4">
              <div className="flex-1 min-w-0">
                <h1 className="text-2xl sm:text-3xl font-semibold text-neutral-900 dark:text-neutral-50 mb-1">
                  Explore Learning
                </h1>
                <p className="text-xs sm:text-sm text-neutral-600 dark:text-neutral-400">
                  Discover courses, materials, and educational content
                </p>
              </div>
              <Button
                variant="primary"
                size="sm"
                className="flex items-center gap-1.5 sm:gap-2 flex-shrink-0"
                onClick={handleCreateCourse}
              >
                <Plus className="w-4 h-4" />
                <span className="hidden sm:inline">Create Course</span>
                <span className="sm:hidden">Create</span>
              </Button>
            </div>

            {/* Search Bar */}
            <div className="mb-4">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-neutral-400" />
                <input
                  type="text"
                  placeholder="Search courses, materials..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full pl-10 pr-4 py-2.5 rounded-lg border border-neutral-200 dark:border-neutral-800 bg-white dark:bg-neutral-900 text-neutral-900 dark:text-neutral-50 placeholder-neutral-400 focus:outline-none focus:ring-2 focus:ring-brand-purple-500 focus:border-transparent text-sm sm:text-base"
                />
              </div>
            </div>

            {/* Tabs */}
            <div className="flex items-center gap-2 mb-4">
              <button
                onClick={() => setActiveTab('courses')}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 flex items-center gap-2 ${
                  activeTab === 'courses'
                    ? 'bg-brand-purple-600 text-white'
                    : 'bg-transparent text-neutral-600 dark:text-neutral-400 hover:text-neutral-900 dark:hover:text-neutral-50'
                }`}
              >
                <BookOpen className="w-4 h-4" />
                Courses
              </button>
              <button
                onClick={() => setActiveTab('materials')}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 flex items-center gap-2 ${
                  activeTab === 'materials'
                    ? 'bg-brand-purple-600 text-white'
                    : 'bg-transparent text-neutral-600 dark:text-neutral-400 hover:text-neutral-900 dark:hover:text-neutral-50'
                }`}
              >
                <FileText className="w-4 h-4" />
                Materials
              </button>
            </div>

            {/* Sort Options */}
            <div className="flex items-center gap-2 overflow-x-auto scrollbar-hide pb-1">
              {(['newest', 'popular', 'rating', 'price_asc'] as SortType[]).map((sort) => (
                <button
                  key={sort}
                  onClick={() => setSortBy(sort)}
                  className={`px-3 sm:px-4 py-1.5 sm:py-2 rounded-full text-xs sm:text-sm font-medium whitespace-nowrap transition-all duration-200 flex-shrink-0 ${
                    sortBy === sort
                      ? 'bg-brand-purple-600 text-white'
                      : 'bg-transparent border border-neutral-200 dark:border-neutral-800 text-neutral-600 dark:text-neutral-400 hover:border-brand-purple-500 hover:text-brand-purple-600 dark:hover:text-brand-purple-400'
                  }`}
                >
                  {sort === 'newest' && 'Newest'}
                  {sort === 'popular' && 'Popular'}
                  {sort === 'rating' && 'Top Rated'}
                  {sort === 'price_asc' && 'Price: Low to High'}
                </button>
              ))}
            </div>
          </div>

          {/* Content */}
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <div className="w-8 h-8 border-2 border-brand-purple-600 border-t-transparent rounded-full animate-spin" />
            </div>
          ) : error ? (
            <div className="text-center py-12">
              <p className="text-neutral-600 dark:text-neutral-400">{error}</p>
            </div>
          ) : activeTab === 'courses' ? (
            courses.length === 0 ? (
              <div className="text-center py-12">
                <BookOpen className="w-12 h-12 mx-auto mb-4 text-neutral-400" />
                <p className="text-neutral-600 dark:text-neutral-400">No courses found</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6">
                {courses.map((course) => (
                  <div
                    key={course.id}
                    onClick={() => handleCourseClick(course.id)}
                    className="bg-white dark:bg-neutral-900 rounded-lg overflow-hidden border border-neutral-200 dark:border-neutral-800 cursor-pointer transition-all duration-200 hover:shadow-lg active:opacity-70"
                  >
                    {/* Cover Image */}
                    {course.cover_image_url ? (
                      <div className="relative w-full aspect-video bg-neutral-100 dark:bg-neutral-800">
                        <img
                          src={course.cover_image_url}
                          alt={course.title}
                          className="w-full h-full object-cover"
                        />
                        {course.is_free && (
                          <div className="absolute top-2 right-2 bg-green-500 text-white text-xs font-semibold px-2 py-1 rounded">
                            Free
                          </div>
                        )}
                      </div>
                    ) : (
                      <div className="w-full aspect-video bg-gradient-to-br from-brand-purple-500 to-brand-purple-600 flex items-center justify-center">
                        <BookOpen className="w-12 h-12 text-white/50" />
                        {course.is_free && (
                          <div className="absolute top-2 right-2 bg-green-500 text-white text-xs font-semibold px-2 py-1 rounded">
                            Free
                          </div>
                        )}
                      </div>
                    )}

                    {/* Content */}
                    <div className="p-4">
                      <div className="flex items-start justify-between gap-2 mb-2">
                        <h3 className="font-semibold text-neutral-900 dark:text-neutral-50 text-sm sm:text-base line-clamp-2 flex-1">
                          {course.title}
                        </h3>
                        {!course.is_free && course.price && (
                          <span className="text-sm font-semibold text-brand-purple-600 flex-shrink-0">
                            ${course.price}
                          </span>
                        )}
                      </div>

                      {/* Creator */}
                      {course.creator && (
                        <div className="flex items-center gap-2 mb-3">
                          <Avatar
                            src={course.creator.profile_picture}
                            alt={course.creator.display_name || course.creator.username}
                            size="sm"
                          />
                          <span className="text-xs text-neutral-600 dark:text-neutral-400 truncate">
                            {course.creator.display_name || course.creator.username}
                          </span>
                          {course.creator.is_verified && (
                            <VerifiedBadge size="sm" />
                          )}
                        </div>
                      )}

                      {/* Meta Info */}
                      <div className="flex items-center gap-3 text-xs text-neutral-600 dark:text-neutral-400 mb-3">
                        <span className={`px-2 py-0.5 rounded ${getDifficultyColor(course.difficulty_level)}`}>
                          {course.difficulty_level}
                        </span>
                        {course.estimated_duration && (
                          <span className="flex items-center gap-1">
                            <Clock className="w-3 h-3" />
                            {formatDuration(course.estimated_duration)}
                          </span>
                        )}
                        {course.total_lessons > 0 && (
                          <span className="flex items-center gap-1">
                            <Play className="w-3 h-3" />
                            {course.total_lessons} lessons
                          </span>
                        )}
                      </div>

                      {/* Stats */}
                      <div className="flex items-center gap-4 text-xs text-neutral-600 dark:text-neutral-400 pt-3 border-t border-neutral-200 dark:border-neutral-800">
                        <span className="flex items-center gap-1">
                          <Users className="w-3 h-3" />
                          {course.enrollment_count}
                        </span>
                        {course.average_rating > 0 && (
                          <span className="flex items-center gap-1">
                            <Star className="w-3 h-3 fill-yellow-400 text-yellow-400" />
                            {course.average_rating.toFixed(1)}
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )
          ) : (
            materials.length === 0 ? (
              <div className="text-center py-12">
                <FileText className="w-12 h-12 mx-auto mb-4 text-neutral-400" />
                <p className="text-neutral-600 dark:text-neutral-400">No materials found</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6">
                {materials.map((material) => (
                  <div
                    key={material.id}
                    onClick={() => handleMaterialClick(material.id)}
                    className="bg-white dark:bg-neutral-900 rounded-lg overflow-hidden border border-neutral-200 dark:border-neutral-800 cursor-pointer transition-all duration-200 hover:shadow-lg active:opacity-70"
                  >
                    {/* Cover Image */}
                    {material.cover_image_url ? (
                      <div className="relative w-full aspect-video bg-neutral-100 dark:bg-neutral-800">
                        <img
                          src={material.cover_image_url}
                          alt={material.title}
                          className="w-full h-full object-cover"
                        />
                        {material.is_free && (
                          <div className="absolute top-2 right-2 bg-green-500 text-white text-xs font-semibold px-2 py-1 rounded">
                            Free
                          </div>
                        )}
                      </div>
                    ) : (
                      <div className="w-full aspect-video bg-gradient-to-br from-brand-purple-500 to-brand-purple-600 flex items-center justify-center">
                        {material.material_type === 'video' ? (
                          <Video className="w-12 h-12 text-white/50" />
                        ) : material.material_type === 'ebook' ? (
                          <BookOpen className="w-12 h-12 text-white/50" />
                        ) : (
                          <FileText className="w-12 h-12 text-white/50" />
                        )}
                        {material.is_free && (
                          <div className="absolute top-2 right-2 bg-green-500 text-white text-xs font-semibold px-2 py-1 rounded">
                            Free
                          </div>
                        )}
                      </div>
                    )}

                    {/* Content */}
                    <div className="p-4">
                      <div className="flex items-start justify-between gap-2 mb-2">
                        <h3 className="font-semibold text-neutral-900 dark:text-neutral-50 text-sm sm:text-base line-clamp-2 flex-1">
                          {material.title}
                        </h3>
                        {!material.is_free && material.price && (
                          <span className="text-sm font-semibold text-brand-purple-600 flex-shrink-0">
                            ${material.price}
                          </span>
                        )}
                      </div>

                      <div className="flex items-center gap-2 mb-3">
                        <span className="text-xs px-2 py-0.5 rounded bg-neutral-100 dark:bg-neutral-800 text-neutral-600 dark:text-neutral-400">
                          {material.material_type}
                        </span>
                        {material.category && (
                          <span className="text-xs text-neutral-600 dark:text-neutral-400">
                            {material.category}
                          </span>
                        )}
                      </div>

                      {/* Stats */}
                      <div className="flex items-center gap-4 text-xs text-neutral-600 dark:text-neutral-400 pt-3 border-t border-neutral-200 dark:border-neutral-800">
                        <span className="flex items-center gap-1">
                          <TrendingUp className="w-3 h-3" />
                          {material.view_count} views
                        </span>
                        {material.download_count > 0 && (
                          <span className="flex items-center gap-1">
                            <Download className="w-3 h-3" />
                            {material.download_count}
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )
          )}
        </div>
      </div>
    </MainLayout>
  );
}
