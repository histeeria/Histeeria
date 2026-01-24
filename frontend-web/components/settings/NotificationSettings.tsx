'use client';

/**
 * Notification Settings Component
 * Allows users to configure notification preferences
 */

import { useState, useEffect } from 'react';
import { CheckCheck } from 'lucide-react';
import { Card } from '@/components/ui/Card';
import { notificationAPI, NotificationPreferences } from '@/lib/api/notifications';

export default function NotificationSettings() {
  const [preferences, setPreferences] = useState<NotificationPreferences | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');

  useEffect(() => {
    loadPreferences();
  }, []);

  const loadPreferences = async () => {
    try {
      const response = await notificationAPI.getPreferences();
      setPreferences(response.preferences);
    } catch (error) {
      console.error('Failed to load preferences:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSave = async () => {
    if (!preferences) return;

    setIsSaving(true);
    setSuccessMessage('');

    try {
      await notificationAPI.updatePreferences({
        email_enabled: preferences.email_enabled,
        email_types: preferences.email_types,
        email_frequency: preferences.email_frequency,
        in_app_enabled: preferences.in_app_enabled,
        push_enabled: preferences.push_enabled,
        inline_actions_enabled: preferences.inline_actions_enabled,
        categories_enabled: preferences.categories_enabled,
      });

      setSuccessMessage('Preferences saved successfully');
      setTimeout(() => setSuccessMessage(''), 3000);
    } catch (error) {
      console.error('Failed to save preferences:', error);
    } finally {
      setIsSaving(false);
    }
  };

  if (isLoading) {
    return (
      <Card variant="solid">
        <div className="p-6 text-center">
          <div className="inline-block w-8 h-8 border-3 border-brand-purple-600 border-t-transparent rounded-full animate-spin" />
          <p className="mt-2 text-sm text-neutral-500">Loading preferences...</p>
        </div>
      </Card>
    );
  }

  if (!preferences) {
    return (
      <Card variant="solid">
        <div className="p-6 text-center">
          <p className="text-sm text-neutral-600 dark:text-neutral-400">Failed to load preferences</p>
        </div>
      </Card>
    );
  }

  return (
    <div className="space-y-5">
      {/* Success Message */}
      {successMessage && (
        <div className="p-4 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg flex items-center gap-3">
          <CheckCheck className="w-5 h-5 text-green-600 dark:text-green-400" />
          <p className="text-sm font-medium text-green-700 dark:text-green-300">{successMessage}</p>
        </div>
      )}

      {/* In-App Notifications */}
      <Card variant="solid">
        <div className="p-6">
          <h3 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50 mb-4">
            In-App Notifications
          </h3>

          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="font-medium text-neutral-700 dark:text-neutral-300">Enable notifications</p>
                <p className="text-sm text-neutral-500 dark:text-neutral-400">
                  Receive notifications in the app
                </p>
              </div>
              <label className="relative inline-block w-12 h-6 cursor-pointer">
                <input
                  type="checkbox"
                  checked={preferences.in_app_enabled}
                  onChange={(e) => setPreferences({ ...preferences, in_app_enabled: e.target.checked })}
                  className="sr-only peer"
                />
                <div className="w-full h-full bg-neutral-300 dark:bg-neutral-700 peer-checked:bg-brand-purple-600 dark:peer-checked:bg-brand-purple-600 rounded-full peer-focus:ring-2 peer-focus:ring-brand-purple-300 dark:peer-focus:ring-brand-purple-800 transition-colors" />
                <div className="absolute top-0.5 left-0.5 w-5 h-5 bg-white dark:bg-white rounded-full peer-checked:translate-x-6 transition-transform shadow-sm" />
              </label>
            </div>

            <div className="flex items-center justify-between">
              <div>
                <p className="font-medium text-neutral-700 dark:text-neutral-300">Inline actions</p>
                <p className="text-sm text-neutral-500 dark:text-neutral-400">
                  Show action buttons in notifications
                </p>
              </div>
              <label className="relative inline-block w-12 h-6 cursor-pointer">
                <input
                  type="checkbox"
                  checked={preferences.inline_actions_enabled}
                  onChange={(e) => setPreferences({ ...preferences, inline_actions_enabled: e.target.checked })}
                  className="sr-only peer"
                />
                <div className="w-full h-full bg-neutral-300 dark:bg-neutral-700 peer-checked:bg-brand-purple-600 dark:peer-checked:bg-brand-purple-600 rounded-full peer-focus:ring-2 peer-focus:ring-brand-purple-300 dark:peer-focus:ring-brand-purple-800 transition-colors" />
                <div className="absolute top-0.5 left-0.5 w-5 h-5 bg-white dark:bg-white rounded-full peer-checked:translate-x-6 transition-transform shadow-sm" />
              </label>
            </div>
          </div>
        </div>
      </Card>

      {/* Email Notifications */}
      <Card variant="solid">
        <div className="p-6">
          <h3 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50 mb-4">
            Email Notifications
          </h3>

          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="font-medium text-neutral-700 dark:text-neutral-300">Enable email notifications</p>
                <p className="text-sm text-neutral-500 dark:text-neutral-400">
                  Receive important notifications via email
                </p>
              </div>
              <label className="relative inline-block w-12 h-6 cursor-pointer">
                <input
                  type="checkbox"
                  checked={preferences.email_enabled}
                  onChange={(e) => setPreferences({ ...preferences, email_enabled: e.target.checked })}
                  className="sr-only peer"
                />
                <div className="w-full h-full bg-neutral-300 dark:bg-neutral-700 peer-checked:bg-brand-purple-600 dark:peer-checked:bg-brand-purple-600 rounded-full peer-focus:ring-2 peer-focus:ring-brand-purple-300 dark:peer-focus:ring-brand-purple-800 transition-colors" />
                <div className="absolute top-0.5 left-0.5 w-5 h-5 bg-white dark:bg-white rounded-full peer-checked:translate-x-6 transition-transform shadow-sm" />
              </label>
            </div>

            {preferences.email_enabled && (
              <>
                <div>
                  <label className="block text-sm font-medium text-neutral-700 dark:text-neutral-300 mb-2">
                    Email frequency
                  </label>
                  <select
                    value={preferences.email_frequency}
                    onChange={(e) => setPreferences({ ...preferences, email_frequency: e.target.value as any })}
                    className="w-full px-4 py-2 bg-white dark:bg-neutral-800 border border-neutral-300 dark:border-neutral-700 rounded-lg text-neutral-900 dark:text-neutral-50 focus:outline-none focus:ring-2 focus:ring-brand-purple-500"
                  >
                    <option value="instant">Instant (as they happen)</option>
                    <option value="daily">Daily digest</option>
                    <option value="weekly">Weekly digest</option>
                    <option value="never">Never</option>
                  </select>
                </div>

                <div>
                  <p className="text-sm font-medium text-neutral-700 dark:text-neutral-300 mb-3">
                    Which types to email:
                  </p>
                  <div className="space-y-2">
                    {Object.entries(preferences.email_types).map(([type, enabled]) => (
                      <label key={type} className="flex items-center gap-3 p-3 hover:bg-neutral-50 dark:hover:bg-neutral-800/50 rounded-lg cursor-pointer">
                        <input
                          type="checkbox"
                          checked={enabled}
                          onChange={(e) => setPreferences({
                            ...preferences,
                            email_types: { ...preferences.email_types, [type]: e.target.checked }
                          })}
                          className="w-4 h-4 text-brand-purple-600 border-neutral-300 dark:border-neutral-600 rounded focus:ring-brand-purple-500"
                        />
                        <span className="text-sm text-neutral-700 dark:text-neutral-300 capitalize">
                          {type.replace(/_/g, ' ')}
                        </span>
                      </label>
                    ))}
                  </div>
                </div>
              </>
            )}
          </div>
        </div>
      </Card>

      {/* Category Filters */}
      <Card variant="solid">
        <div className="p-6">
          <h3 className="text-lg font-semibold text-neutral-900 dark:text-neutral-50 mb-4">
            Notification Categories
          </h3>

          <p className="text-sm text-neutral-600 dark:text-neutral-400 mb-4">
            Choose which categories of notifications you want to receive
          </p>

          <div className="space-y-2">
            {Object.entries(preferences.categories_enabled).map(([category, enabled]) => (
              <label key={category} className="flex items-center gap-3 p-3 hover:bg-neutral-50 dark:hover:bg-neutral-800/50 rounded-lg cursor-pointer">
                <input
                  type="checkbox"
                  checked={enabled}
                  onChange={(e) => setPreferences({
                    ...preferences,
                    categories_enabled: { ...preferences.categories_enabled, [category]: e.target.checked }
                  })}
                  className="w-4 h-4 text-brand-purple-600 border-neutral-300 dark:border-neutral-600 rounded focus:ring-brand-purple-500"
                />
                <span className="text-sm font-medium text-neutral-700 dark:text-neutral-300 capitalize">
                  {category}
                </span>
              </label>
            ))}
          </div>
        </div>
      </Card>

      {/* Save Button */}
      <div className="flex justify-end">
        <button
          onClick={handleSave}
          disabled={isSaving}
          className="px-6 py-2.5 bg-brand-purple-600 hover:bg-brand-purple-700 text-white font-medium rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isSaving ? 'Saving...' : 'Save Preferences'}
        </button>
      </div>
    </div>
  );
}

