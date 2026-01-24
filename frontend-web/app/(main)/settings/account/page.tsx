'use client';

/**
 * Account Settings Page
 * Instagram-style: transparent, full-width, no borders
 */

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { MainLayout } from '@/components/layout/MainLayout';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Avatar } from '@/components/ui/Avatar';
import { ArrowLeft, Upload } from 'lucide-react';
import { useUser } from '@/lib/hooks/useUser';
import GenderSelect from '@/components/ui/GenderSelect';
import ProfilePictureEditor from '@/components/profile/ProfilePictureEditor';

export default function AccountSettingsPage() {
  const router = useRouter();
  const { user, loading, refetch } = useUser();
  const [isLoading, setIsLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [uploadLoading, setUploadLoading] = useState(false);
  const [pictureEditorOpen, setPictureEditorOpen] = useState(false);
  const [emailChangeLoading, setEmailChangeLoading] = useState(false);
  const [usernameChangeLoading, setUsernameChangeLoading] = useState(false);
  
  const [formData, setFormData] = useState({
    display_name: '',
    age: '',
    bio: '',
    location: '',
    gender: '',
    gender_custom: '',
    website: '',
  });

  const [socialLinks, setSocialLinks] = useState({
    twitter: '',
    instagram: '',
    facebook: '',
    linkedin: '',
    github: '',
    youtube: '',
  });

  const [emailData, setEmailData] = useState({
    new_email: '',
    password: '',
    verification_code: '',
  });

  const [emailChangeStep, setEmailChangeStep] = useState<'input' | 'verify'>('input');

  const [usernameData, setUsernameData] = useState({
    new_username: '',
    password: '',
  });

  useEffect(() => {
    if (user) {
      setFormData({
        display_name: user.display_name,
        age: user.age?.toString() || '',
        bio: user.bio || '',
        location: user.location || '',
        gender: user.gender || '',
        gender_custom: user.gender_custom || '',
        website: user.website || '',
      });
      
      if (user.social_links) {
        setSocialLinks({
          twitter: user.social_links.twitter || '',
          instagram: user.social_links.instagram || '',
          facebook: user.social_links.facebook || '',
          linkedin: user.social_links.linkedin || '',
          github: user.social_links.github || '',
          youtube: user.social_links.youtube || '',
        });
      }
    }
  }, [user]);

  const handleUpdateProfile = async () => {
    setIsLoading(true);
    setMessage('');
    
    try {
      const token = localStorage.getItem('token');
      const payload: any = {
        display_name: formData.display_name,
        age: parseInt(formData.age),
        bio: formData.bio || null,
        location: formData.location || null,
        gender: formData.gender || null,
        gender_custom: formData.gender === 'custom' ? formData.gender_custom || null : null,
        website: formData.website || null,
      };

      const response = await fetch('/api/proxy/v1/account/profile/basic', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify(payload),
      });

      const data = await response.json();
      
      if (response.ok) {
        setMessage('Profile updated successfully');
        refetch();
      } else {
        setMessage(data.message || 'Failed to update profile');
      }
    } catch (error) {
      setMessage('Network error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  const handleProfilePictureUpload = async (compressedFile: File) => {
    setUploadLoading(true);
    setMessage('');
    
    const formData = new FormData();
    formData.append('profile_picture', compressedFile);

    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/proxy/v1/account/profile-picture', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` },
        body: formData,
      });
      
      const data = await response.json();
      
      if (response.ok) {
        setMessage('Profile picture updated successfully');
        refetch();
      } else {
        throw new Error(data.message || 'Upload failed');
      }
    } catch (error: any) {
      throw error;
    } finally {
      setUploadLoading(false);
    }
  };

  const handleUpdateSocialLinks = async () => {
    setIsLoading(true);
    setMessage('');
    
    try {
      const token = localStorage.getItem('token');
      const payload = {
        twitter: socialLinks.twitter || null,
        instagram: socialLinks.instagram || null,
        facebook: socialLinks.facebook || null,
        linkedin: socialLinks.linkedin || null,
        github: socialLinks.github || null,
        youtube: socialLinks.youtube || null,
      };

      const response = await fetch('/api/proxy/v1/account/profile/social-links', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify(payload),
      });

      const data = await response.json();
      
      if (response.ok) {
        setMessage('Social links updated successfully');
        refetch();
      } else {
        setMessage(data.message || 'Failed to update social links');
      }
    } catch (error) {
      setMessage('Network error occurred');
    } finally {
      setIsLoading(false);
    }
  };

  const handleChangeEmail = async () => {
    setEmailChangeLoading(true);
    setMessage('');

    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/proxy/v1/account/change-email', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify({
          new_email: emailData.new_email,
          password: emailData.password,
        }),
      });

      const data = await response.json();
      
      if (response.ok) {
        setMessage('Verification code sent to new email');
        setEmailChangeStep('verify');
      } else {
        setMessage(data.message || 'Failed to change email');
      }
    } catch (error) {
      setMessage('Network error');
    } finally {
      setEmailChangeLoading(false);
    }
  };

  const handleVerifyEmailChange = async () => {
    if (!emailData.verification_code || emailData.verification_code.length !== 6) {
      setMessage('Please enter a valid 6-digit code');
      return;
    }

    setEmailChangeLoading(true);
    setMessage('');

    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/proxy/v1/account/verify-email-change', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify({
          verification_code: emailData.verification_code,
        }),
      });
      
      const data = await response.json();
      
      if (response.ok) {
        setMessage('Email changed successfully');
        setEmailData({ new_email: '', password: '', verification_code: '' });
        setEmailChangeStep('input');
        refetch();
      } else {
        setMessage(data.message || 'Invalid verification code');
      }
    } catch (error) {
      setMessage('Network error');
    } finally {
      setEmailChangeLoading(false);
    }
  };

  const handleChangeUsername = async () => {
    setUsernameChangeLoading(true);
    setMessage('');

    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/proxy/v1/account/change-username', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify({
          new_username: usernameData.new_username,
          password: usernameData.password,
        }),
      });

      const data = await response.json();
      
      if (response.ok) {
        setMessage('Username changed successfully');
        setUsernameData({ new_username: '', password: '' });
        refetch();
      } else {
        setMessage(data.message || 'Failed to change username');
      }
    } catch (error) {
      setMessage('Network error');
    } finally {
      setUsernameChangeLoading(false);
    }
  };

  if (loading) {
    return (
      <MainLayout>
        <div className="min-h-screen bg-white dark:bg-neutral-950 flex items-center justify-center">
          <div className="text-center">
            <div className="w-8 h-8 border-4 border-brand-purple-600 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
            <p className="text-sm text-neutral-600 dark:text-neutral-400">Loading...</p>
          </div>
        </div>
      </MainLayout>
    );
  }

  return (
    <MainLayout>
      <div className="min-h-screen bg-white dark:bg-neutral-950">
        <div className="w-full">
          {/* Header */}
          <div className="flex items-center gap-4 px-4 py-4 border-b border-neutral-200 dark:border-neutral-800">
            <button
              onClick={() => router.push('/settings')}
              className="p-1 -ml-1 rounded-full transition-colors"
            >
              <ArrowLeft className="w-6 h-6 text-neutral-900 dark:text-neutral-50" />
            </button>
            <h1 className="text-xl font-semibold text-neutral-900 dark:text-neutral-50">
              Account
            </h1>
          </div>

          {/* Message */}
          {message && (
            <div className={`mx-4 mt-4 p-3 rounded-lg text-sm ${
              message.includes('success') 
                ? 'bg-green-50 dark:bg-green-900/20 text-green-700 dark:text-green-300' 
                : 'bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-300'
            }`}>
              {message}
            </div>
          )}

          <div className="w-full">
            {/* Profile Picture */}
            <div className="px-4 py-6 border-b border-neutral-200 dark:border-neutral-800">
              <div className="flex items-center gap-4">
                <Avatar 
                  src={user?.profile_picture} 
                  alt="Profile" 
                  fallback={user?.display_name || 'User'} 
                  size="xl" 
                />
                <div>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPictureEditorOpen(true)}
                    disabled={uploadLoading}
                  >
                    <Upload className="w-4 h-4 mr-2" />
                    Change Photo
                  </Button>
                  <p className="text-xs text-neutral-500 dark:text-neutral-400 mt-2">
                    JPG, PNG or GIF. Max 5MB
                  </p>
                </div>
              </div>
            </div>

            {/* Basic Information */}
            <div className="px-4 py-6 space-y-6 border-b border-neutral-200 dark:border-neutral-800">
              <h3 className="text-base font-semibold text-neutral-900 dark:text-neutral-50">
                Basic Information
              </h3>
              <div className="space-y-4">
                <Input
                  label="Display Name"
                  value={formData.display_name}
                  onChange={(e) => setFormData({ ...formData, display_name: e.target.value })}
                />
                
                <Input
                  label="Age"
                  type="number"
                  value={formData.age}
                  onChange={(e) => setFormData({ ...formData, age: e.target.value })}
                />

                <div>
                  <label className="block text-sm font-medium text-neutral-700 dark:text-neutral-300 mb-2">
                    Bio
                  </label>
                  <textarea
                    value={formData.bio}
                    onChange={(e) => setFormData({ ...formData, bio: e.target.value })}
                    placeholder="Tell us about yourself..."
                    maxLength={150}
                    rows={3}
                    className="w-full px-4 py-3 rounded-lg border border-neutral-200 dark:border-neutral-800 bg-transparent text-neutral-900 dark:text-neutral-50 placeholder-neutral-400 dark:placeholder-neutral-500 focus:outline-none focus:ring-2 focus:ring-brand-purple-500 focus:border-brand-purple-500 resize-none"
                  />
                  <div className="mt-1 text-xs text-neutral-500 text-right">
                    {formData.bio.length} / 150
                  </div>
                </div>

                <Input
                  label="Location"
                  value={formData.location}
                  onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                  placeholder="e.g., New York, USA"
                />

                <div>
                  <label className="block text-sm font-medium text-neutral-700 dark:text-neutral-300 mb-2">
                    Gender
                  </label>
                  <GenderSelect
                    value={formData.gender}
                    customValue={formData.gender_custom}
                    onChange={(gender, customValue) => 
                      setFormData({ ...formData, gender: gender || '', gender_custom: customValue || '' })
                    }
                  />
                </div>

                <Input
                  label="Website"
                  type="url"
                  value={formData.website}
                  onChange={(e) => setFormData({ ...formData, website: e.target.value })}
                  placeholder="https://yourwebsite.com"
                />

                <Button 
                  variant="primary" 
                  onClick={handleUpdateProfile}
                  isLoading={isLoading}
                  className="w-full"
                >
                  Save Changes
                </Button>
              </div>
            </div>

            {/* Social Links */}
            <div className="px-4 py-6 space-y-4 border-b border-neutral-200 dark:border-neutral-800">
              <h3 className="text-base font-semibold text-neutral-900 dark:text-neutral-50">
                Social Media Links
              </h3>
              <div className="space-y-3">
                <Input
                  label="X (Twitter)"
                  type="url"
                  value={socialLinks.twitter}
                  onChange={(e) => setSocialLinks({ ...socialLinks, twitter: e.target.value })}
                  placeholder="https://twitter.com/username"
                />
                
                <Input
                  label="Instagram"
                  type="url"
                  value={socialLinks.instagram}
                  onChange={(e) => setSocialLinks({ ...socialLinks, instagram: e.target.value })}
                  placeholder="https://instagram.com/username"
                />
                
                <Input
                  label="Facebook"
                  type="url"
                  value={socialLinks.facebook}
                  onChange={(e) => setSocialLinks({ ...socialLinks, facebook: e.target.value })}
                  placeholder="https://facebook.com/username"
                />
                
                <Input
                  label="LinkedIn"
                  type="url"
                  value={socialLinks.linkedin}
                  onChange={(e) => setSocialLinks({ ...socialLinks, linkedin: e.target.value })}
                  placeholder="https://linkedin.com/in/username"
                />

                <Input
                  label="GitHub"
                  type="url"
                  value={socialLinks.github}
                  onChange={(e) => setSocialLinks({ ...socialLinks, github: e.target.value })}
                  placeholder="https://github.com/username"
                />

                <Input
                  label="YouTube"
                  type="url"
                  value={socialLinks.youtube}
                  onChange={(e) => setSocialLinks({ ...socialLinks, youtube: e.target.value })}
                  placeholder="https://youtube.com/@username"
                />

                <Button 
                  variant="primary" 
                  onClick={handleUpdateSocialLinks}
                  isLoading={isLoading}
                  className="w-full"
                >
                  Save Social Links
                </Button>
              </div>
            </div>

            {/* Email */}
            <div className="px-4 py-6 space-y-4 border-b border-neutral-200 dark:border-neutral-800">
              <h3 className="text-base font-semibold text-neutral-900 dark:text-neutral-50">
                Email Address
              </h3>
              <div className="space-y-4">
                <div className="p-3 bg-neutral-50 dark:bg-neutral-900/50 rounded-lg">
                  <p className="text-xs text-neutral-500 dark:text-neutral-400 mb-1">Current Email</p>
                  <p className="text-sm font-medium text-neutral-900 dark:text-neutral-50">{user?.email}</p>
                </div>
                
                {emailChangeStep === 'input' ? (
                  <>
                    <Input
                      label="New Email"
                      type="email"
                      value={emailData.new_email}
                      onChange={(e) => setEmailData({ ...emailData, new_email: e.target.value })}
                    />
                    
                    <Input
                      label="Password"
                      type="password"
                      value={emailData.password}
                      onChange={(e) => setEmailData({ ...emailData, password: e.target.value })}
                    />
                    
                    <Button 
                      variant="outline" 
                      onClick={handleChangeEmail}
                      isLoading={emailChangeLoading}
                      className="w-full"
                    >
                      Send Verification Code
                    </Button>
                  </>
                ) : (
                  <>
                    <div className="p-3 bg-brand-purple-50 dark:bg-brand-purple-900/30 rounded-lg">
                      <p className="text-xs font-medium text-brand-purple-700 dark:text-brand-purple-300">
                        Code sent to: {emailData.new_email}
                      </p>
                    </div>
                    
                    <Input
                      label="Verification Code"
                      type="text"
                      maxLength={6}
                      value={emailData.verification_code}
                      onChange={(e) => setEmailData({ ...emailData, verification_code: e.target.value })}
                      placeholder="Enter 6-digit code"
                    />
                    
                    <div className="flex gap-2">
                      <Button 
                        variant="primary" 
                        onClick={handleVerifyEmailChange}
                        isLoading={emailChangeLoading}
                        className="flex-1"
                      >
                        Verify & Change
                      </Button>
                      <Button 
                        variant="ghost" 
                        onClick={() => {
                          setEmailChangeStep('input');
                          setEmailData({ new_email: '', password: '', verification_code: '' });
                          setMessage('');
                        }}
                        disabled={emailChangeLoading}
                      >
                        Cancel
                      </Button>
                    </div>
                  </>
                )}
              </div>
            </div>

            {/* Username */}
            <div className="px-4 py-6 space-y-4">
              <h3 className="text-base font-semibold text-neutral-900 dark:text-neutral-50">
                Username
              </h3>
              <div className="space-y-4">
                <div className="p-3 bg-neutral-50 dark:bg-neutral-900 rounded-lg">
                  <p className="text-xs text-neutral-500 dark:text-neutral-400 mb-1">Current Username</p>
                  <p className="text-sm font-medium text-neutral-900 dark:text-neutral-50">@{user?.username}</p>
                </div>
                
                <Input
                  label="New Username"
                  value={usernameData.new_username}
                  onChange={(e) => setUsernameData({ ...usernameData, new_username: e.target.value })}
                />
                
                <Input
                  label="Password"
                  type="password"
                  value={usernameData.password}
                  onChange={(e) => setUsernameData({ ...usernameData, password: e.target.value })}
                />
                
                <Button 
                  variant="outline" 
                  onClick={handleChangeUsername}
                  isLoading={usernameChangeLoading}
                  className="w-full"
                >
                  Change Username
                </Button>
                
                <p className="text-xs text-neutral-500 dark:text-neutral-400">
                  Can be changed once every 30 days
                </p>
              </div>
            </div>
          </div>

          {/* Profile Picture Editor Modal */}
          <ProfilePictureEditor
            isOpen={pictureEditorOpen}
            onClose={() => setPictureEditorOpen(false)}
            onSave={handleProfilePictureUpload}
            currentImageUrl={user?.profile_picture || null}
          />
        </div>
      </div>
    </MainLayout>
  );
}
