'use client';

/**
 * StatVisibilitySettings Component
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Manage which profile stats are visible (minimum 3 required)
 */

import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/Button';
import { Eye, EyeOff, AlertTriangle } from 'lucide-react';

interface StatVisibilitySettingsProps {
  initialVisibility?: { [key: string]: boolean };
  onSave?: (visibility: { [key: string]: boolean }) => Promise<void>;
}

interface StatOption {
  key: string;
  label: string;
  description: string;
}

const statOptions: StatOption[] = [
  { key: 'posts', label: 'Posts', description: 'Number of posts you\'ve created' },
  { key: 'projects', label: 'Projects', description: 'Number of projects you\'ve worked on' },
  { key: 'followers', label: 'Followers', description: 'People following you' },
  { key: 'following', label: 'Following', description: 'People you\'re following' },
  { key: 'connections', label: 'Connections', description: 'Your professional connections' },
  { key: 'collaborators', label: 'Collaborators', description: 'People you\'re collaborating with' },
];

export default function StatVisibilitySettings({ 
  initialVisibility, 
  onSave 
}: StatVisibilitySettingsProps) {
  const [visibility, setVisibility] = useState<{ [key: string]: boolean }>({
    posts: true,
    projects: true,
    followers: true,
    following: true,
    connections: true,
    collaborators: true,
  });
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  useEffect(() => {
    if (initialVisibility) {
      setVisibility({ ...visibility, ...initialVisibility });
    }
  }, [initialVisibility]);

  const visibleCount = Object.values(visibility).filter(Boolean).length;
  const canToggle = (key: string) => {
    // If turning off, check if we'll still have at least 3 visible
    if (visibility[key]) {
      return visibleCount > 3;
    }
    // Can always turn on
    return true;
  };

  const toggleStat = (key: string) => {
    if (!canToggle(key)) {
      setMessage({
        type: 'error',
        text: 'You must keep at least 3 stats visible on your profile.',
      });
      setTimeout(() => setMessage(null), 3000);
      return;
    }

    setVisibility(prev => ({
      ...prev,
      [key]: !prev[key],
    }));
    setMessage(null);
  };

  const handleSave = async () => {
    // Validate minimum 3 stats
    if (visibleCount < 3) {
      setMessage({
        type: 'error',
        text: 'You must have at least 3 stats visible.',
      });
      return;
    }

    setSaving(true);
    setMessage(null);

    try {
      console.log('[StatVisibility] Saving:', visibility);
      
      // Save to backend
      const token = localStorage.getItem('token');
      const response = await fetch('/api/proxy/v1/account/stat-visibility', {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ stat_visibility: visibility }),
      });

      console.log('[StatVisibility] Response status:', response.status);
      
      if (response.ok) {
        const data = await response.json();
        console.log('[StatVisibility] Success:', data);
        
        setMessage({
          type: 'success',
          text: 'Stat visibility settings saved successfully!',
        });
        
        // Call parent onSave callback to refresh user data
        if (onSave) {
          await onSave(visibility);
        }
        
        setTimeout(() => setMessage(null), 3000);
      } else {
        const data = await response.json();
        console.error('[StatVisibility] Error:', data);
        setMessage({
          type: 'error',
          text: data.message || `Failed to save settings (${response.status})`,
        });
      }
    } catch (error: any) {
      console.error('[StatVisibility] Exception:', error);
      setMessage({
        type: 'error',
        text: `Error: ${error.message || 'An error occurred while saving settings'}`,
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h3 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50 mb-2">
          Profile Stats Visibility
        </h3>
        <p className="text-sm text-neutral-600 dark:text-neutral-400">
          Choose which stats appear on your profile. At least 3 stats must be visible.
        </p>
      </div>

      {/* Visible Count Indicator */}
      <div className={`
        flex items-center gap-2 px-4 py-3 rounded-lg border
        ${visibleCount >= 3 
          ? 'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800' 
          : 'bg-orange-50 dark:bg-orange-900/20 border-orange-200 dark:border-orange-800'
        }
      `}>
        {visibleCount >= 3 ? (
          <Eye className="w-5 h-5 text-green-600 dark:text-green-400" />
        ) : (
          <AlertTriangle className="w-5 h-5 text-orange-600 dark:text-orange-400" />
        )}
        <span className={`text-sm font-medium ${
          visibleCount >= 3 
            ? 'text-green-700 dark:text-green-300' 
            : 'text-orange-700 dark:text-orange-300'
        }`}>
          {visibleCount} of 6 stats visible {visibleCount < 3 && '(Minimum 3 required)'}
        </span>
      </div>

      {/* Message */}
      {message && (
        <div className={`
          px-4 py-3 rounded-lg border
          ${message.type === 'success' 
            ? 'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800 text-green-700 dark:text-green-300' 
            : 'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800 text-red-700 dark:text-red-300'
          }
        `}>
          {message.text}
        </div>
      )}

      {/* Stat Options */}
      <div className="space-y-3">
        {statOptions.map((stat) => {
          const isVisible = visibility[stat.key];
          const isDisabled = isVisible && visibleCount <= 3;

          return (
            <button
              key={stat.key}
              onClick={() => toggleStat(stat.key)}
              disabled={isDisabled}
              className={`
                w-full flex items-center justify-between p-4 rounded-lg border transition-all
                ${isVisible 
                  ? 'bg-brand-purple-50 dark:bg-brand-purple-900/20 border-brand-purple-200 dark:border-brand-purple-800' 
                  : 'bg-neutral-50 dark:bg-neutral-800 border-neutral-200 dark:border-neutral-700'
                }
                ${isDisabled ? 'opacity-60 cursor-not-allowed' : 'hover:shadow-md cursor-pointer'}
              `}
            >
              <div className="flex items-center gap-3 flex-1">
                <div className={`
                  w-10 h-10 rounded-full flex items-center justify-center
                  ${isVisible 
                    ? 'bg-brand-purple-600 text-white' 
                    : 'bg-neutral-200 dark:bg-neutral-700 text-neutral-600 dark:text-neutral-400'
                  }
                `}>
                  {isVisible ? <Eye className="w-5 h-5" /> : <EyeOff className="w-5 h-5" />}
                </div>
                <div className="text-left">
                  <div className="font-medium text-neutral-900 dark:text-neutral-50">
                    {stat.label}
                  </div>
                  <div className="text-sm text-neutral-600 dark:text-neutral-400">
                    {stat.description}
                  </div>
                </div>
              </div>
              {isDisabled && (
                <span className="text-xs text-neutral-500 dark:text-neutral-400">
                  Required
                </span>
              )}
            </button>
          );
        })}
      </div>

      {/* Save Button */}
      <div className="flex justify-end">
        <Button
          variant="primary"
          onClick={handleSave}
          disabled={saving || visibleCount < 3}
        >
          {saving ? 'Saving...' : 'Save Changes'}
        </Button>
      </div>
    </div>
  );
}

