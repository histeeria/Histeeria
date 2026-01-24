'use client';

/**
 * Professional Profile Page - Instagram-Style with Wantedly Features
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Clean, professional profile system with privacy controls
 * Instagram-like layout with Wantedly's professional touch
 */

import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { MainLayout } from '@/components/layout/MainLayout';
import { Avatar } from '@/components/ui/Avatar';
import { Button } from '@/components/ui/Button';
import ProfilePrivacyGuard from '@/components/profile/ProfilePrivacyGuard';
import InlineEditor from '@/components/profile/InlineEditor';
import VerifiedBadge from '@/components/ui/VerifiedBadge';
import ExperienceCard from '@/components/profile/ExperienceCard';
import EducationCard from '@/components/profile/EducationCard';
import ExperienceModal from '@/components/profile/ExperienceModal';
import EducationModal from '@/components/profile/EducationModal';
import RelationshipButton from '@/components/social/RelationshipButton';
import ProfileStats from '@/components/social/ProfileStats';
import { useUser } from '@/lib/hooks/useUser';
import { useMessages } from '@/lib/contexts/MessagesContext';
import { 
  MapPin, 
  Link as LinkIcon, 
  Calendar, 
  User as UserIcon,
  Edit3,
  Plus,
  CheckCircle2,
  Briefcase,
  GraduationCap,
  Award,
  Target,
  Share2,
  Grid3x3,
  Users,
  Rocket,
  FileText,
  Lock,
  Globe,
  Eye,
  MessageCircle
} from 'lucide-react';
import { 
  FaXTwitter, 
  FaInstagram, 
  FaFacebook, 
  FaLinkedin, 
  FaGithub, 
  FaYoutube 
} from 'react-icons/fa6';

const tabs = [
  { id: 'Feed', label: 'Feed', icon: Grid3x3 },
  { id: 'Communities', label: 'Communities', icon: Users },
  { id: 'Projects', label: 'Projects', icon: Rocket },
  { id: 'About', label: 'About', icon: FileText },
];

interface PublicProfile {
  id: string;
  username: string;
  display_name: string;
  profile_picture: string | null;
  is_verified: boolean;
  bio: string | null;
  location: string | null;
  gender: string | null;
  gender_custom: string | null;
  age: number | null;
  website: string | null;
  joined_at: string;
  story: string | null;
  ambition: string | null;
  posts_count: number;
  followers_count: number;
  following_count: number;
  projects_count: number;
  is_own_profile: boolean;
  profile_privacy?: string; // Only returned for own profile
  social_links?: {
    twitter?: string | null;
    instagram?: string | null;
    facebook?: string | null;
    linkedin?: string | null;
    github?: string | null;
    youtube?: string | null;
  };
}

export default function ProfilePage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const viewUsername = searchParams.get('u'); // View other user's profile
  const { user: currentUser, loading: currentUserLoading } = useUser();
  const { openMessages } = useMessages();
  
  const [profile, setProfile] = useState<PublicProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState('About');
  const [shareMessage, setShareMessage] = useState('');
  const [previewMode, setPreviewMode] = useState(false); // Preview as public
  
  // Inline editing states
  const [storyEditorOpen, setStoryEditorOpen] = useState(false);
  const [ambitionEditorOpen, setAmbitionEditorOpen] = useState(false);
  const [isStoryExpanded, setIsStoryExpanded] = useState(false);
  const [isAmbitionExpanded, setIsAmbitionExpanded] = useState(false);
  const [expandedExperiences, setExpandedExperiences] = useState<Set<string>>(new Set());
  const [expandedEducation, setExpandedEducation] = useState<Set<string>>(new Set());
  
  // Experience and Education states
  const [experiences, setExperiences] = useState<any[]>([]);
  const [education, setEducation] = useState<any[]>([]);
  const [experienceModalOpen, setExperienceModalOpen] = useState(false);
  const [educationModalOpen, setEducationModalOpen] = useState(false);
  const [editingExperience, setEditingExperience] = useState<any | null>(null);
  const [editingEducation, setEditingEducation] = useState<any | null>(null);
  
  // Relationship status state
  const [relationshipStatus, setRelationshipStatus] = useState<any>(null);

  useEffect(() => {
    if (!currentUserLoading) {
      fetchProfile();
    }
  }, [currentUserLoading, viewUsername, currentUser?.stat_visibility]);

  useEffect(() => {
    // Fetch experiences and education after profile is loaded
    if (profile?.is_own_profile) {
      fetchExperiences();
      fetchEducation();
    }
  }, [profile]);

  const fetchProfile = async () => {
    try {
      setLoading(true);
      setError(null);

      // Determine which profile to fetch
      const username = viewUsername || currentUser?.username;
      
      if (!username) {
        setError('No username specified');
        setLoading(false);
        return;
      }

      const token = localStorage.getItem('token');
      // Add cache buster to force fresh data
      const cacheBuster = `?t=${Date.now()}`;
      const response = await fetch(`/api/proxy/v1/profile/${username}${cacheBuster}`, {
        headers: token ? { 'Authorization': `Bearer ${token}` } : {},
        cache: 'no-store', // Disable caching
      });

      if (response.ok) {
        const data = await response.json();
        console.log('Profile data fetched:', data.profile);
        console.log('Stat visibility from profile:', data.profile?.stat_visibility);
        setProfile(data.profile);
      } else {
        const data = await response.json();
        setError(data.message || 'Failed to fetch profile');
      }
    } catch (err) {
      setError('Network error occurred');
      console.error('Profile fetch error:', err);
    } finally {
      setLoading(false);
    }
  };

  const fetchExperiences = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/proxy/v1/account/experiences', {
        headers: { 'Authorization': `Bearer ${token}` },
      });
      if (response.ok) {
        const data = await response.json();
        console.log('Experiences fetched:', data);
        setExperiences(data.experiences || []);
      } else {
        console.error('Failed to fetch experiences:', response.status);
      }
    } catch (err) {
      console.error('Failed to fetch experiences:', err);
    }
  };

  const fetchEducation = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/proxy/v1/account/education', {
        headers: { 'Authorization': `Bearer ${token}` },
      });
      if (response.ok) {
        const data = await response.json();
        console.log('Education fetched:', data);
        setEducation(data.education || []);
      } else {
        console.error('Failed to fetch education:', response.status);
      }
    } catch (err) {
      console.error('Failed to fetch education:', err);
    }
  };

  const handleSaveStory = async (value: string | null) => {
    const token = localStorage.getItem('token');
    const response = await fetch('/api/proxy/v1/account/profile/story', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify({ story: value }),
    });

    if (!response.ok) {
      const data = await response.json();
      throw new Error(data.message || 'Failed to save story');
    }

    // Refresh profile
    await fetchProfile();
  };

  const handleSaveAmbition = async (value: string | null) => {
    const token = localStorage.getItem('token');
    const response = await fetch('/api/proxy/v1/account/profile/ambition', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify({ ambition: value }),
    });

    if (!response.ok) {
      const data = await response.json();
      throw new Error(data.message || 'Failed to save ambition');
    }

    // Refresh profile
    await fetchProfile();
  };

  const formatJoinedDate = (dateStr: string) => {
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
  };

  const getGenderDisplay = (gender: string | null, customGender: string | null) => {
    if (!gender) return null;
    if (gender === 'custom' && customGender) return customGender;
    const genderMap: { [key: string]: string } = {
      'male': 'Male',
      'female': 'Female',
      'non-binary': 'Non-binary',
      'prefer-not-to-say': 'Prefer not to say',
    };
    return genderMap[gender] || gender;
  };

  // Social media platform config with branded icons
  const getSocialPlatformConfig = () => [
    { key: 'twitter', icon: FaXTwitter, label: 'X (Twitter)', color: '#000000' },
    { key: 'instagram', icon: FaInstagram, label: 'Instagram', color: '#E1306C' },
    { key: 'facebook', icon: FaFacebook, label: 'Facebook', color: '#1877F2' },
    { key: 'linkedin', icon: FaLinkedin, label: 'LinkedIn', color: '#0A66C2' },
    { key: 'github', icon: FaGithub, label: 'GitHub', color: '#181717' },
    { key: 'youtube', icon: FaYoutube, label: 'YouTube', color: '#FF0000' },
  ];

  // Check if a field should be visible based on preview mode and field visibility settings
  const isFieldVisible = (fieldName: string) => {
    if (!previewMode || !profile?.is_own_profile) {
      return true; // Always show when not in preview mode or viewing someone else's profile
    }
    // In preview mode, respect the field_visibility settings from user's own data
    return currentUser?.field_visibility?.[fieldName] !== false;
  };

  // Handle message button click
  const handleMessageClick = () => {
    if (!profile) return;
    
    // On mobile: use overlay (via MessagesContext)
    if (window.innerWidth < 768) {
      openMessages(profile.id);
    } else {
      // On desktop: navigate to messages page with userId param
      router.push(`/messages?userId=${profile.id}`);
    }
  };

  const handleShareProfile = async () => {
    const profileUrl = `${window.location.origin}/profile?u=${profile?.username}`;
    
    if (navigator.share) {
      try {
        await navigator.share({
          title: `${profile?.display_name} (@${profile?.username})`,
          text: profile?.bio || `Check out ${profile?.display_name}'s profile on Upvista`,
          url: profileUrl,
        });
      } catch (err) {
        // User cancelled or error occurred
      }
    } else {
      // Fallback: Copy to clipboard
      try {
        await navigator.clipboard.writeText(profileUrl);
        setShareMessage('Profile link copied!');
        setTimeout(() => setShareMessage(''), 3000);
      } catch (err) {
        setShareMessage('Failed to copy link');
        setTimeout(() => setShareMessage(''), 3000);
      }
    }
  };

  // Experience CRUD handlers
  const handleSaveExperience = async (data: any) => {
    const token = localStorage.getItem('token');
    const url = editingExperience
      ? `/api/proxy/v1/account/experiences/${editingExperience.id}`
      : '/api/proxy/v1/account/experiences';
    
    const response = await fetch(url, {
      method: editingExperience ? 'PATCH' : 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.message || 'Failed to save experience');
    }

    await fetchExperiences();
    setEditingExperience(null);
  };

  const handleDeleteExperience = async (id: string) => {
    if (!confirm('Are you sure you want to delete this experience?')) return;

    const token = localStorage.getItem('token');
    const response = await fetch(`/api/proxy/v1/account/experiences/${id}`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${token}` },
    });

    if (response.ok) {
      await fetchExperiences();
    }
  };

  // Education CRUD handlers
  const handleSaveEducation = async (data: any) => {
    const token = localStorage.getItem('token');
    const url = editingEducation
      ? `/api/proxy/v1/account/education/${editingEducation.id}`
      : '/api/proxy/v1/account/education';
    
    const response = await fetch(url, {
      method: editingEducation ? 'PATCH' : 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.message || 'Failed to save education');
    }

    await fetchEducation();
    setEditingEducation(null);
  };

  const handleDeleteEducation = async (id: string) => {
    if (!confirm('Are you sure you want to delete this education?')) return;

    const token = localStorage.getItem('token');
    const response = await fetch(`/api/proxy/v1/account/education/${id}`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${token}` },
    });

    if (response.ok) {
      await fetchEducation();
    }
  };

  return (
    <ProfilePrivacyGuard isLoading={loading || currentUserLoading} error={error}>
      <MainLayout>
        {profile && (
          <div className="max-w-4xl mx-auto">
            {/* Instagram-Style Profile Header */}
            <div className="p-4 md:p-6 mb-1">
              {/* Mobile Layout */}
              <div className="md:hidden">
                {/* Avatar and Name - Full Width */}
                <div className="flex items-start gap-3 mb-4">
                  {/* Avatar */}
                  <div className="flex-shrink-0">
                    <Avatar
                      src={profile.profile_picture}
                      alt={profile.display_name}
                      fallback={profile.display_name}
                      size="2xl"
                      className={profile.is_own_profile ? 'ring-2 ring-brand-purple-500' : ''}
                    />
                  </div>
                  
                  {/* Name and Username - Full width without share button */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-1.5 mb-0.5">
                      <h1 className="text-xl font-bold text-brand-purple-600 dark:text-brand-purple-400 truncate">
                        {profile.display_name}
                      </h1>
                    </div>
                    <div className="flex items-center gap-1.5 flex-wrap">
                      <p className="text-sm text-neutral-500 dark:text-neutral-400">
                        @{profile.username}
                      </p>
                      
                      {/* Verified Badge - Always show */}
                      <VerifiedBadge size="sm" variant="badge" showText={true} isVerified={profile.is_verified} />
                      
                      {/* Privacy Indicator */}
                      {profile.is_own_profile && (
                        <>
                          {profile.profile_privacy === 'private' && (
                            <div className="flex items-center gap-1 px-2 py-0.5 border border-neutral-200 dark:border-neutral-800 rounded-full text-xs text-neutral-500 dark:text-neutral-400">
                              <Lock className="w-3 h-3" />
                              <span>Private</span>
                            </div>
                          )}
                          {profile.profile_privacy === 'connections' && (
                            <div className="flex items-center gap-1 px-2 py-0.5 border border-neutral-200 dark:border-neutral-800 rounded-full text-xs text-neutral-500 dark:text-neutral-400">
                              <Users className="w-3 h-3" />
                              <span>Connections</span>
                            </div>
                          )}
                          {profile.profile_privacy === 'public' && (
                            <div className="flex items-center gap-1 px-2 py-0.5 border border-neutral-200 dark:border-neutral-800 rounded-full text-xs text-neutral-500 dark:text-neutral-400">
                              <Globe className="w-3 h-3" />
                              <span>Public</span>
                            </div>
                          )}
                        </>
                      )}
                    </div>

                    {/* Share Button - Below name */}
                    <div className="mt-2">
                      <Button 
                        variant="secondary" 
                        size="sm"
                        onClick={handleShareProfile}
                      >
                        <Share2 className="w-4 h-4" />
                        Share Profile
                      </Button>
                    </div>
                  </div>
                </div>

                {/* Bio - Above Stats */}
                {profile.bio && (
                  <p className="text-sm text-neutral-700 dark:text-neutral-300 mb-3">
                    {profile.bio}
                  </p>
                )}

                {/* Stats */}
                <div className="mb-3">
                  <ProfileStats
                    userId={profile.id}
                    isOwnProfile={profile.is_own_profile}
                    profileData={profile}
                    statVisibility={(profile as any).stat_visibility || currentUser?.stat_visibility}
                    onStatClick={(type) => {
                      // Navigate to relationships list page
                      if (type === 'followers' || type === 'following' || type === 'connections' || type === 'collaborators') {
                        router.push(`/profile/${profile.username}/${type}?userId=${profile.id}`);
                      }
                    }}
                  />
                </div>

                {/* Meta Info */}

                <div className="space-y-1 text-sm text-neutral-600 dark:text-neutral-400">
                  {/* Location, Age, Gender - Inline on Mobile */}
                  <div className="flex items-center gap-3 flex-wrap">
                    {profile.location && isFieldVisible('location') && (
                      <div className="flex items-center gap-1">
                        <MapPin className="w-4 h-4" />
                        <span>{profile.location}</span>
                      </div>
                    )}
                    
                    {profile.age && isFieldVisible('age') && (
                      <div className="flex items-center gap-1">
                        <span>{profile.age} years old</span>
                      </div>
                    )}
                    
                    {profile.gender && getGenderDisplay(profile.gender, profile.gender_custom) && isFieldVisible('gender') && (
                      <div className="flex items-center gap-1">
                        <UserIcon className="w-4 h-4" />
                        <span>{getGenderDisplay(profile.gender, profile.gender_custom)}</span>
                      </div>
                    )}
                  </div>
                  
                  {/* Website */}
                  {profile.website && isFieldVisible('website') && (
                    <a 
                      href={profile.website} 
                      target="_blank" 
                      rel="noopener noreferrer"
                      className="flex items-center gap-1 text-brand-purple-600 dark:text-brand-purple-400"
                    >
                      <LinkIcon className="w-4 h-4" />
                      <span>{new URL(profile.website).hostname}</span>
                    </a>
                  )}
                  
                  {/* Joined Date */}
                  {isFieldVisible('joined_date') && (
                    <div className="flex items-center gap-1">
                      <Calendar className="w-4 h-4" />
                      <span>Joined {formatJoinedDate(profile.joined_at)}</span>
                    </div>
                  )}
                </div>

                {/* Social Links - Mobile */}
                {profile.social_links && (
                  <div className="flex items-center gap-3 flex-wrap mt-3">
                    {getSocialPlatformConfig().map((platform) => {
                      const link = profile.social_links?.[platform.key as keyof typeof profile.social_links];
                      if (!link) return null;
                      
                      const Icon = platform.icon;
                      
                      return (
                        <a
                          key={platform.key}
                          href={link}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="w-9 h-9 rounded-full flex items-center justify-center transition-all hover:scale-110 cursor-pointer border border-neutral-200 dark:border-neutral-800 hover:border-brand-purple-500"
                          title={platform.label}
                        >
                          <Icon 
                            size={20} 
                            className="text-neutral-900 dark:text-neutral-50"
                          />
                        </a>
                      );
                    })}
                  </div>
                )}

                {/* Action Buttons at Bottom - Mobile Only */}
                {profile.is_own_profile && !previewMode ? (
                  <div className="flex gap-2 mt-3">
                    <Button 
                      variant="secondary" 
                      size="sm"
                      onClick={() => router.push('/settings/account')}
                      className="flex-1 text-xs py-2"
                    >
                      <Edit3 className="w-3.5 h-3.5" />
                      Edit Profile
                    </Button>
                    <Button 
                      variant="secondary" 
                      size="sm"
                      onClick={() => setPreviewMode(true)}
                      className="flex-1 text-xs py-2"
                    >
                      <Eye className="w-3.5 h-3.5" />
                      Preview
                    </Button>
                  </div>
                ) : (
                  <div className="flex gap-2 mt-4">
                    {previewMode && (
                      <Button 
                        variant="primary"
                        size="sm"
                        onClick={() => setPreviewMode(false)}
                        className="flex-1"
                      >
                        Exit Preview
                      </Button>
                    )}
                    {(!profile.is_own_profile || previewMode) && (
                      <>
                        <div className="flex-1">
                          <RelationshipButton
                            targetUserId={profile.id}
                            onStatusChange={setRelationshipStatus}
                          />
                        </div>
                        <Button 
                          variant="secondary" 
                          size="sm"
                          className="flex-1"
                          onClick={handleMessageClick}
                        >
                          <MessageCircle className="w-4 h-4" />
                          Message
                        </Button>
                      </>
                    )}
                  </div>
                )}
              </div>

              {/* Desktop Layout */}
              <div className="hidden md:flex gap-8">
                {/* Avatar */}
                <div className="flex-shrink-0">
                  <Avatar
                    src={profile.profile_picture}
                    alt={profile.display_name}
                    fallback={profile.display_name}
                    size="3xl"
                    className={profile.is_own_profile ? 'ring-4 ring-brand-purple-500/20' : ''}
                  />
                </div>

                {/* Info Section */}
                <div className="flex-1 min-w-0">
                  {/* Username and Actions */}
                  <div className="flex items-center gap-4 mb-5">
                    <h1 className="text-xl font-normal text-neutral-900 dark:text-neutral-50">
                      {profile.username}
                    </h1>
                    
                    {profile.is_own_profile && !previewMode ? (
                      <>
                        <Button 
                          variant="secondary"
                          size="sm"
                          onClick={() => setPreviewMode(true)}
                        >
                          <Eye className="w-4 h-4" />
                          Preview
                        </Button>
                        <Button 
                          variant="secondary" 
                          size="sm"
                          onClick={() => router.push('/settings/account')}
                        >
                          <Edit3 className="w-4 h-4" />
                          Edit Profile
                        </Button>
                        <Button 
                          variant="secondary" 
                          size="sm"
                          onClick={handleShareProfile}
                        >
                          <Share2 className="w-4 h-4" />
                        </Button>
                      </>
                    ) : (
                      <>
                        {previewMode && (
                          <Button 
                            variant="primary"
                            size="sm"
                            onClick={() => setPreviewMode(false)}
                          >
                            Exit Preview
                          </Button>
                        )}
                        {(!profile.is_own_profile || previewMode) && (
                          <>
                            <RelationshipButton
                              targetUserId={profile.id}
                              onStatusChange={setRelationshipStatus}
                            />
                            <Button 
                              variant="secondary" 
                              size="sm"
                              onClick={handleMessageClick}
                            >
                              <MessageCircle className="w-4 h-4" />
                              Message
                            </Button>
                            <Button 
                              variant="secondary" 
                              size="sm"
                              onClick={handleShareProfile}
                            >
                              <Share2 className="w-4 h-4" />
                            </Button>
                          </>
                        )}
                      </>
                    )}
                  </div>

                  {/* Name, Verified Badge, and Privacy */}
                  <div className="mb-2">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="text-xl font-bold text-brand-purple-600 dark:text-brand-purple-400">
                        {profile.display_name}
                      </span>
                      
                      {/* Verified Badge - Always show */}
                      <VerifiedBadge size="md" variant="badge" showText={true} isVerified={profile.is_verified} />
                      
                      {/* Privacy Indicator */}
                      {profile.is_own_profile && (
                        <>
                          {profile.profile_privacy === 'private' && (
                            <div className="flex items-center gap-1 px-2 py-0.5 border border-neutral-200 dark:border-neutral-800 rounded-full text-xs text-neutral-600 dark:text-neutral-400">
                              <Lock className="w-3 h-3" />
                              <span>Private</span>
                            </div>
                          )}
                          {profile.profile_privacy === 'connections' && (
                            <div className="flex items-center gap-1 px-2 py-0.5 border border-neutral-200 dark:border-neutral-800 rounded-full text-xs text-neutral-600 dark:text-neutral-400">
                              <Users className="w-3 h-3" />
                              <span>Connections</span>
                            </div>
                          )}
                          {profile.profile_privacy === 'public' && (
                            <div className="flex items-center gap-1 px-2 py-0.5 border border-neutral-200 dark:border-neutral-800 rounded-full text-xs text-neutral-600 dark:text-neutral-400">
                              <Globe className="w-3 h-3" />
                              <span>Public</span>
                            </div>
                          )}
                        </>
                      )}
                    </div>
                  </div>

                  {/* Bio */}
                  {profile.bio && (
                    <p className="text-sm text-neutral-700 dark:text-neutral-300 mb-3">
                      {profile.bio}
                    </p>
                  )}

                  {/* Stats - Below Bio */}
                  <div className="mb-3">
                    <ProfileStats
                      userId={profile.id}
                      isOwnProfile={profile.is_own_profile}
                      profileData={profile}
                      statVisibility={(profile as any).stat_visibility || currentUser?.stat_visibility}
                      onStatClick={(type) => {
                        // Navigate to relationships list page
                        if (type === 'followers' || type === 'following' || type === 'connections' || type === 'collaborators') {
                          router.push(`/profile/${profile.username}/${type}?userId=${profile.id}`);
                        }
                      }}
                    />
                  </div>

                  {/* Meta Info */}
                  <div className="space-y-1 text-sm text-neutral-600 dark:text-neutral-400">
                    {/* Location, Age, Gender - Inline on Desktop */}
                    <div className="flex items-center gap-3 flex-wrap">
                      {profile.location && isFieldVisible('location') && (
                        <div className="flex items-center gap-1">
                          <MapPin className="w-4 h-4" />
                          <span>{profile.location}</span>
                        </div>
                      )}
                      
                      {profile.age && isFieldVisible('age') && (
                        <div className="flex items-center gap-1">
                          <span>{profile.age} years old</span>
                        </div>
                      )}
                      
                      {profile.gender && getGenderDisplay(profile.gender, profile.gender_custom) && isFieldVisible('gender') && (
                        <div className="flex items-center gap-1">
                          <UserIcon className="w-4 h-4" />
                          <span>{getGenderDisplay(profile.gender, profile.gender_custom)}</span>
                        </div>
                      )}
                    </div>
                    
                    {/* Website */}
                    {profile.website && isFieldVisible('website') && (
                      <a 
                        href={profile.website} 
                        target="_blank" 
                        rel="noopener noreferrer"
                        className="flex items-center gap-1 text-brand-purple-600 dark:text-brand-purple-400 hover:underline"
                      >
                        <LinkIcon className="w-4 h-4" />
                        <span>{new URL(profile.website).hostname}</span>
                      </a>
                    )}
                    
                    {/* Joined Date */}
                    {isFieldVisible('joined_date') && (
                      <div className="flex items-center gap-1">
                        <Calendar className="w-4 h-4" />
                        <span>Joined {formatJoinedDate(profile.joined_at)}</span>
                      </div>
                    )}

                    {/* Social Links - Desktop */}
                    {profile.social_links && (
                      <div className="flex items-center gap-2 flex-wrap mt-2">
                        {getSocialPlatformConfig().map((platform) => {
                          const link = profile.social_links?.[platform.key as keyof typeof profile.social_links];
                          if (!link) return null;
                          
                          const Icon = platform.icon;
                          
                          return (
                            <a
                              key={platform.key}
                              href={link}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="w-8 h-8 rounded-full flex items-center justify-center transition-all hover:scale-110 cursor-pointer border border-neutral-200 dark:border-neutral-800 hover:border-brand-purple-500"
                              title={platform.label}
                            >
                              <Icon 
                                size={18} 
                                className="text-neutral-900 dark:text-neutral-50"
                              />
                            </a>
                          );
                        })}
                      </div>
                    )}
                  </div>
                </div>
              </div>

              {/* Preview Mode Banner */}
              {previewMode && profile.is_own_profile && (
                <div className="mt-4 p-3 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg">
                  <div className="flex items-center justify-center gap-2 text-sm text-blue-800 dark:text-blue-200">
                    <Eye className="w-4 h-4" />
                    <span className="font-medium">Preview Mode:</span>
                    <span>This is how others see your profile based on your privacy settings</span>
                  </div>
                </div>
              )}

              {/* Share Message */}
              {shareMessage && (
                <div className="mt-4 p-3 bg-green-50 dark:bg-green-900/20 text-green-800 dark:text-green-200 rounded-lg text-sm text-center">
                  {shareMessage}
                </div>
              )}
            </div>

            {/* Tabs - Instagram Style */}
            <div className="mt-4 border-b border-neutral-200 dark:border-neutral-800">
              <div className="grid grid-cols-4 md:flex md:justify-center md:gap-12">
                {tabs.map((tab) => {
                  const Icon = tab.icon;
                  return (
                    <button
                      key={tab.id}
                      onClick={() => setActiveTab(tab.id)}
                      className={`
                        flex flex-col md:flex-row items-center justify-center gap-1 md:gap-2 py-3 md:py-4 text-xs md:text-sm font-semibold transition-colors border-t-2
                        ${activeTab === tab.id
                          ? 'border-neutral-900 dark:border-neutral-50 text-neutral-900 dark:text-neutral-50'
                          : 'border-transparent text-neutral-400 dark:text-neutral-600 hover:text-neutral-600 dark:hover:text-neutral-400'
                        }
                      `}
                    >
                      <Icon className="w-5 h-5 md:w-4 md:h-4" />
                      <span className="hidden md:inline">{tab.label}</span>
                      <span className="md:hidden text-[10px]">{tab.label}</span>
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Tab Content */}
            {activeTab === 'Feed' && (
              <div className="mt-4 p-6">
                <div className="text-center py-16">
                  <div className="w-20 h-20 mx-auto mb-6 border border-neutral-200 dark:border-neutral-800 rounded-full flex items-center justify-center">
                    <Grid3x3 className="w-10 h-10 text-neutral-400" />
                  </div>
                  <h3 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
                    No Posts Yet
                  </h3>
                  <p className="text-base text-neutral-600 dark:text-neutral-400">
                    Start sharing your ideas and connect with the community!
                  </p>
                </div>
              </div>
            )}

            {activeTab === 'Communities' && (
              <div className="mt-4 p-6">
                <div className="text-center py-16">
                  <div className="w-20 h-20 mx-auto mb-6 border border-neutral-200 dark:border-neutral-800 rounded-full flex items-center justify-center">
                    <Users className="w-10 h-10 text-neutral-400" />
                  </div>
                  <h3 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
                    No Communities Joined
                  </h3>
                  <p className="text-base text-neutral-600 dark:text-neutral-400">
                    Discover and join communities that match your interests!
                  </p>
                </div>
              </div>
            )}

            {activeTab === 'Projects' && (
              <div className="mt-4 p-6">
                <div className="text-center py-16">
                  <div className="w-20 h-20 mx-auto mb-6 border border-neutral-200 dark:border-neutral-800 rounded-full flex items-center justify-center">
                    <Rocket className="w-10 h-10 text-neutral-400" />
                  </div>
                  <h3 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
                    No Projects Added
                  </h3>
                  <p className="text-base text-neutral-600 dark:text-neutral-400">
                    Showcase your work and achievements here!
                  </p>
                </div>
              </div>
            )}

            {activeTab === 'About' && (
              <div className="mt-4 space-y-4">
                {/* Tell Your Story */}
                <div className="p-6 border-b border-neutral-200 dark:border-neutral-800">
                  <div className="flex items-start justify-between mb-4">
                    <h3 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50">
                      {(profile.is_own_profile && !previewMode) ? (profile.story ? 'My Story' : 'Add Your Story') : 'My Story'}
                    </h3>
                    {profile.is_own_profile && !previewMode && (
                      <button
                        onClick={() => setStoryEditorOpen(true)}
                        className="text-brand-purple-600 hover:text-brand-purple-700 transition-colors"
                      >
                        {profile.story ? (
                          <Edit3 className="w-5 h-5" />
                        ) : (
                          <Plus className="w-5 h-5" />
                        )}
                      </button>
                    )}
                  </div>
                  
                  {profile.story ? (
                    <div className="w-full max-w-full overflow-hidden">
                      <p className="text-base text-neutral-700 dark:text-neutral-300 whitespace-pre-wrap break-words max-w-full" style={{ overflowWrap: 'anywhere', wordBreak: 'break-word' }}>
                        {profile.story.length > 250 && !isStoryExpanded
                          ? `${profile.story.slice(0, 250)}...`
                          : profile.story
                        }
                      </p>
                      {profile.story.length > 250 && (
                        <button
                          onClick={() => setIsStoryExpanded(!isStoryExpanded)}
                          className="mt-2 text-sm font-medium text-brand-purple-600 hover:text-brand-purple-700 transition-colors cursor-pointer"
                        >
                          {isStoryExpanded ? 'Show less' : 'Read more'}
                        </button>
                      )}
                    </div>
                  ) : profile.is_own_profile ? (
                    <button
                      onClick={() => setStoryEditorOpen(true)}
                      className="w-full py-8 border-2 border-dashed border-neutral-300 dark:border-neutral-700 rounded-xl hover:border-brand-purple-500 hover:bg-brand-purple-50 dark:hover:bg-brand-purple-900/10 transition-colors text-neutral-500 dark:text-neutral-400 hover:text-brand-purple-600"
                    >
                      <Plus className="w-6 h-6 mx-auto mb-2" />
                      <span className="text-sm font-medium">Add your story</span>
                    </button>
                  ) : (
                    <p className="text-neutral-500 dark:text-neutral-400 italic">
                      No story added yet
                    </p>
                  )}
                </div>

                {/* Ambition */}
                <div className="p-6 border-b border-neutral-200 dark:border-neutral-800">
                  <div className="flex items-start justify-between mb-4">
                    <div className="flex items-center gap-2">
                      <Target className="w-5 h-5 text-brand-purple-600" />
                      <h3 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50">
                        {(profile.is_own_profile && !previewMode && !profile.ambition) ? 'Add Your Ambition' : 'Ambition'}
                      </h3>
                    </div>
                    {profile.is_own_profile && !previewMode && (
                      <button
                        onClick={() => setAmbitionEditorOpen(true)}
                        className="text-brand-purple-600 hover:text-brand-purple-700 transition-colors"
                      >
                        {profile.ambition ? (
                          <Edit3 className="w-5 h-5" />
                        ) : (
                          <Plus className="w-5 h-5" />
                        )}
                      </button>
                    )}
                  </div>
                  
                  {profile.ambition ? (
                    <div className="w-full max-w-full overflow-hidden">
                      <p className="text-base text-neutral-700 dark:text-neutral-300 whitespace-pre-wrap break-words max-w-full" style={{ overflowWrap: 'anywhere', wordBreak: 'break-word' }}>
                        {profile.ambition.length > 200 && !isAmbitionExpanded
                          ? `${profile.ambition.slice(0, 200)}...`
                          : profile.ambition
                        }
                      </p>
                      {profile.ambition.length > 200 && (
                        <button
                          onClick={() => setIsAmbitionExpanded(!isAmbitionExpanded)}
                          className="mt-2 text-sm font-medium text-brand-purple-600 hover:text-brand-purple-700 transition-colors cursor-pointer"
                        >
                          {isAmbitionExpanded ? 'Show less' : 'Read more'}
                        </button>
                      )}
                    </div>
                  ) : profile.is_own_profile ? (
                    <button
                      onClick={() => setAmbitionEditorOpen(true)}
                      className="w-full py-8 border-2 border-dashed border-neutral-300 dark:border-neutral-700 rounded-xl hover:border-brand-purple-500 hover:bg-brand-purple-50 dark:hover:bg-brand-purple-900/10 transition-colors text-neutral-500 dark:text-neutral-400 hover:text-brand-purple-600"
                    >
                      <Plus className="w-6 h-6 mx-auto mb-2" />
                      <span className="text-sm font-medium">Add your ambition</span>
                    </button>
                  ) : (
                    <p className="text-neutral-500 dark:text-neutral-400 italic">
                      No ambition added yet
                    </p>
                  )}
                </div>

                {/* Experience Section */}
                <div className="p-6 border-b border-neutral-200 dark:border-neutral-800">
                  <div className="flex items-start justify-between mb-6">
                    <div className="flex items-center gap-2">
                      <Briefcase className="w-5 h-5 text-brand-purple-600" />
                      <h3 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50">
                        Experience
                      </h3>
                    </div>
                    {profile.is_own_profile && !previewMode && (
                      <button
                        onClick={() => {
                          setEditingExperience(null);
                          setExperienceModalOpen(true);
                        }}
                        className="text-brand-purple-600 hover:text-brand-purple-700 transition-colors"
                      >
                        <Plus className="w-5 h-5" />
                      </button>
                    )}
                  </div>

                  {experiences.length > 0 ? (
                    <div className="space-y-6">
                      {experiences.map((exp) => (
                        <ExperienceCard
                          key={exp.id}
                          experience={exp}
                          isOwnProfile={profile.is_own_profile && !previewMode}
                          onEdit={() => {
                            setEditingExperience(exp);
                            setExperienceModalOpen(true);
                          }}
                          onDelete={() => handleDeleteExperience(exp.id)}
                        />
                      ))}
                    </div>
                  ) : (profile.is_own_profile && !previewMode) ? (
                    <button
                      onClick={() => {
                        setEditingExperience(null);
                        setExperienceModalOpen(true);
                      }}
                      className="w-full py-8 border-2 border-dashed border-neutral-300 dark:border-neutral-700 rounded-xl hover:border-brand-purple-500 hover:bg-brand-purple-50 dark:hover:bg-brand-purple-900/10 transition-colors text-neutral-500 dark:text-neutral-400 hover:text-brand-purple-600"
                    >
                      <Plus className="w-6 h-6 mx-auto mb-2" />
                      <span className="text-sm font-medium">Add your first experience</span>
                    </button>
                  ) : (
                    <p className="text-neutral-500 dark:text-neutral-400 italic text-center py-4">
                      No experience added yet
                    </p>
                  )}
                </div>

                {/* Education Section */}
                <div className="p-6 border-b border-neutral-200 dark:border-neutral-800">
                  <div className="flex items-start justify-between mb-6">
                    <div className="flex items-center gap-2">
                      <GraduationCap className="w-5 h-5 text-brand-purple-600" />
                      <h3 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50">
                        Education
                      </h3>
                    </div>
                    {profile.is_own_profile && !previewMode && (
                      <button
                        onClick={() => {
                          setEditingEducation(null);
                          setEducationModalOpen(true);
                        }}
                        className="text-brand-purple-600 hover:text-brand-purple-700 transition-colors"
                      >
                        <Plus className="w-5 h-5" />
                      </button>
                    )}
                  </div>

                  {education.length > 0 ? (
                    <div className="space-y-6">
                      {education.map((edu) => (
                        <EducationCard
                          key={edu.id}
                          education={edu}
                          isOwnProfile={profile.is_own_profile && !previewMode}
                          isExpanded={expandedEducation.has(edu.id)}
                          onToggleExpand={() => {
                            setExpandedEducation(prev => {
                              const newSet = new Set(prev);
                              if (newSet.has(edu.id)) {
                                newSet.delete(edu.id);
                              } else {
                                newSet.add(edu.id);
                              }
                              return newSet;
                            });
                          }}
                          onEdit={() => {
                            setEditingEducation(edu);
                            setEducationModalOpen(true);
                          }}
                          onDelete={() => handleDeleteEducation(edu.id)}
                        />
                      ))}
                    </div>
                  ) : (profile.is_own_profile && !previewMode) ? (
                    <button
                      onClick={() => {
                        setEditingEducation(null);
                        setEducationModalOpen(true);
                      }}
                      className="w-full py-8 border-2 border-dashed border-neutral-300 dark:border-neutral-700 rounded-xl hover:border-brand-purple-500 hover:bg-brand-purple-50 dark:hover:bg-brand-purple-900/10 transition-colors text-neutral-500 dark:text-neutral-400 hover:text-brand-purple-600"
                    >
                      <Plus className="w-6 h-6 mx-auto mb-2" />
                      <span className="text-sm font-medium">Add your first education</span>
                    </button>
                  ) : (
                    <p className="text-neutral-500 dark:text-neutral-400 italic text-center py-4">
                      No education added yet
                    </p>
                  )}
                </div>

                {/* Skills & Achievements - Coming Soon */}
                <div className="p-6">
                  <div className="flex items-center gap-2 mb-4">
                    <Award className="w-5 h-5 text-neutral-400" />
                    <h3 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50">
                      Skills & Achievements
                    </h3>
                    <span className="ml-auto text-[10px] px-1.5 py-0.5 rounded-md border border-neutral-200 dark:border-neutral-800 text-neutral-500 font-medium">
                      Coming Soon
                    </span>
                  </div>
                  <p className="text-sm text-neutral-500 dark:text-neutral-400">
                    Highlight your skills and accomplishments
                  </p>
                </div>
              </div>
            )}

            {/* Inline Editors - Only in edit mode */}
            {!previewMode && (
              <>
                <InlineEditor
                  title="Tell Your Story"
                  value={profile.story}
                  maxLength={1000}
                  placeholder="Share your journey, experiences, and what makes you unique..."
                  isOpen={storyEditorOpen}
                  onClose={() => setStoryEditorOpen(false)}
                  onSave={handleSaveStory}
                />

                <InlineEditor
                  title="Your Ambition"
                  value={profile.ambition}
                  maxLength={500}
                  placeholder="What drives you? What are your goals and aspirations?"
                  isOpen={ambitionEditorOpen}
                  onClose={() => setAmbitionEditorOpen(false)}
                  onSave={handleSaveAmbition}
                />

                {/* Experience Modal */}
                <ExperienceModal
                  isOpen={experienceModalOpen}
                  experience={editingExperience}
                  onClose={() => {
                    setExperienceModalOpen(false);
                    setEditingExperience(null);
                  }}
                  onSave={handleSaveExperience}
                />

                {/* Education Modal */}
                <EducationModal
                  isOpen={educationModalOpen}
                  education={editingEducation}
                  onClose={() => {
                    setEducationModalOpen(false);
                    setEditingEducation(null);
                  }}
                  onSave={handleSaveEducation}
                />
              </>
            )}
          </div>
        )}
      </MainLayout>
    </ProfilePrivacyGuard>
  );
}

