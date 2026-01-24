'use client';

/**
 * Privacy Settings Page
 * Instagram-style: transparent, full-width, no borders
 */

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { MainLayout } from '@/components/layout/MainLayout';
import { Button } from '@/components/ui/Button';
import { ArrowLeft } from 'lucide-react';
import { useUser } from '@/lib/hooks/useUser';
import StatVisibilitySettings from '@/components/settings/StatVisibilitySettings';

export default function PrivacySettingsPage() {
  const router = useRouter();
  const { user, loading, refetch } = useUser();
  const [isLoading, setIsLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [privacyData, setPrivacyData] = useState<{
    profile_privacy: string;
    field_visibility: {
      location: boolean;
      gender: boolean;
      age: boolean;
      website: boolean;
      joined_date: boolean;
      email: boolean;
      [key: string]: boolean;
    };
  }>({
    profile_privacy: 'public',
    field_visibility: {
      location: true,
      gender: true,
      age: true,
      website: true,
      joined_date: true,
      email: false,
    },
  });

  useEffect(() => {
    if (user) {
      setPrivacyData({
        profile_privacy: user.profile_privacy || 'public',
        field_visibility: user.field_visibility || {
          location: true,
          gender: true,
          age: true,
          website: true,
          joined_date: true,
          email: false,
        },
      });
    }
  }, [user]);

  const handleUpdatePrivacy = async () => {
    setIsLoading(true);
    setMessage('');

    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/proxy/v1/account/profile/privacy', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify(privacyData),
      });

      const data = await response.json();
      
      if (response.ok) {
        setMessage('Privacy settings updated successfully');
        refetch();
      } else {
        setMessage(data.message || 'Failed to update privacy settings');
      }
    } catch (error) {
      setMessage('Network error occurred');
    } finally {
      setIsLoading(false);
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
              Privacy
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
            {/* Profile Visibility */}
            <div className="px-4 py-6 space-y-3 border-b border-neutral-200 dark:border-neutral-800">
              <h3 className="text-base font-semibold text-neutral-900 dark:text-neutral-50">
                Profile Visibility
              </h3>
              <div className="space-y-1">
                {[
                  { value: 'public', label: 'Public', description: 'Anyone can view your profile' },
                  { value: 'connections', label: 'Connections Only', description: 'Only your connections can view' },
                  { value: 'private', label: 'Private', description: 'Only you can view' },
                ].map((option) => (
                  <label
                    key={option.value}
                    className="flex items-start gap-3 p-3 rounded-lg cursor-pointer"
                  >
                    <input
                      type="radio"
                      name="profile_privacy"
                      value={option.value}
                      checked={privacyData.profile_privacy === option.value}
                      onChange={(e) => setPrivacyData({ ...privacyData, profile_privacy: e.target.value })}
                      className="mt-1 w-4 h-4 text-brand-purple-600 cursor-pointer"
                    />
                    <div>
                      <p className="font-medium text-neutral-900 dark:text-neutral-50">{option.label}</p>
                      <p className="text-sm text-neutral-600 dark:text-neutral-400">{option.description}</p>
                    </div>
                  </label>
                ))}
              </div>
            </div>

            {/* Field Visibility */}
            <div className="px-4 py-6 space-y-4 border-b border-neutral-200 dark:border-neutral-800">
              <div>
                <h3 className="text-base font-semibold text-neutral-900 dark:text-neutral-50 mb-1">
                  Field Visibility
                </h3>
                <p className="text-sm text-neutral-600 dark:text-neutral-400">
                  Control which fields are visible on your public profile
                </p>
              </div>
              
              <div className="space-y-1">
                {[
                  { key: 'location', label: 'Location' },
                  { key: 'gender', label: 'Gender' },
                  { key: 'age', label: 'Age' },
                  { key: 'website', label: 'Website' },
                  { key: 'joined_date', label: 'Joined Date' },
                ].map((field) => (
                  <label
                    key={field.key}
                    className="flex items-center justify-between px-3 py-3 hover:bg-neutral-50 dark:hover:bg-neutral-900/50 transition-colors cursor-pointer rounded-lg"
                  >
                    <span className="font-medium text-neutral-900 dark:text-neutral-50">{field.label}</span>
                    <input
                      type="checkbox"
                      checked={privacyData.field_visibility[field.key] || false}
                      onChange={(e) => setPrivacyData({
                        ...privacyData,
                        field_visibility: {
                          ...privacyData.field_visibility,
                          [field.key]: e.target.checked,
                        },
                      })}
                      className="w-4 h-4 text-brand-purple-600 rounded cursor-pointer"
                    />
                  </label>
                ))}
              </div>

              <Button
                variant="primary"
                onClick={handleUpdatePrivacy}
                isLoading={isLoading}
                className="w-full mt-4"
              >
                Save Privacy Settings
              </Button>
            </div>

            {/* Stats Visibility */}
            <div className="px-4 py-6">
              <StatVisibilitySettings
                initialVisibility={user?.stat_visibility}
                onSave={async () => {
                  await refetch();
                }}
              />
            </div>
          </div>
        </div>
      </div>
    </MainLayout>
  );
}
