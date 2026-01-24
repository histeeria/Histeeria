'use client';

/**
 * Security Settings Page
 * Instagram-style: transparent, full-width, no borders
 */

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { MainLayout } from '@/components/layout/MainLayout';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Badge } from '@/components/ui/Badge';
import { ArrowLeft, Eye, EyeOff } from 'lucide-react';

export default function SecuritySettingsPage() {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [showPasswords, setShowPasswords] = useState({
    current: false,
    new: false,
    confirm: false,
  });
  
  const [passwords, setPasswords] = useState({
    current_password: '',
    new_password: '',
    confirm_password: '',
  });

  const handleChangePassword = async () => {
    if (passwords.new_password !== passwords.confirm_password) {
      setMessage('New passwords do not match');
      return;
    }

    if (passwords.new_password.length < 6) {
      setMessage('Password must be at least 6 characters');
      return;
    }

    setIsLoading(true);
    setMessage('');

    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/proxy/v1/account/change-password', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify({
          current_password: passwords.current_password,
          new_password: passwords.new_password,
          confirm_password: passwords.confirm_password,
        }),
      });

      const data = await response.json();
      
      if (response.ok) {
        setMessage('Password changed successfully');
        setPasswords({ current_password: '', new_password: '', confirm_password: '' });
      } else {
        setMessage(data.message || 'Failed to change password');
      }
    } catch (error) {
      setMessage('Network error');
    } finally {
      setIsLoading(false);
    }
  };

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
              Security
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
            {/* Change Password */}
            <div className="px-4 py-6 space-y-4 border-b border-neutral-200 dark:border-neutral-800">
              <h3 className="text-base font-semibold text-neutral-900 dark:text-neutral-50">
                Change Password
              </h3>
              <div className="space-y-4">
                <div className="relative">
                  <Input 
                    label="Current Password" 
                    type={showPasswords.current ? "text" : "password"}
                    value={passwords.current_password}
                    onChange={(e) => setPasswords({ ...passwords, current_password: e.target.value })}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPasswords({ ...showPasswords, current: !showPasswords.current })}
                    className="absolute right-4 top-1/2 -translate-y-1/2 text-neutral-400 hover:text-neutral-600 dark:hover:text-neutral-300 z-10"
                  >
                    {showPasswords.current ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                  </button>
                </div>
                
                <div className="relative">
                  <Input 
                    label="New Password" 
                    type={showPasswords.new ? "text" : "password"}
                    value={passwords.new_password}
                    onChange={(e) => setPasswords({ ...passwords, new_password: e.target.value })}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPasswords({ ...showPasswords, new: !showPasswords.new })}
                    className="absolute right-4 top-1/2 -translate-y-1/2 text-neutral-400 hover:text-neutral-600 dark:hover:text-neutral-300 z-10"
                  >
                    {showPasswords.new ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                  </button>
                </div>
                
                <div className="relative">
                  <Input 
                    label="Confirm New Password" 
                    type={showPasswords.confirm ? "text" : "password"}
                    value={passwords.confirm_password}
                    onChange={(e) => setPasswords({ ...passwords, confirm_password: e.target.value })}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPasswords({ ...showPasswords, confirm: !showPasswords.confirm })}
                    className="absolute right-4 top-1/2 -translate-y-1/2 text-neutral-400 hover:text-neutral-600 dark:hover:text-neutral-300 z-10"
                  >
                    {showPasswords.confirm ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                  </button>
                </div>
                
                <Button 
                  variant="primary" 
                  onClick={handleChangePassword}
                  isLoading={isLoading}
                  className="w-full"
                >
                  Update Password
                </Button>
              </div>
            </div>

            {/* Two-Factor Authentication */}
            <div className="px-4 py-6 space-y-4">
              <div className="flex items-start justify-between">
                <div>
                  <h3 className="text-base font-semibold text-neutral-900 dark:text-neutral-50 mb-1">
                    Two-Factor Authentication
                  </h3>
                  <p className="text-sm text-neutral-600 dark:text-neutral-400">
                    Add an extra layer of security to your account
                  </p>
                </div>
                <Badge variant="neutral">Coming Soon</Badge>
              </div>
              <Button variant="outline" disabled className="w-full">
                Enable 2FA
              </Button>
            </div>
          </div>
        </div>
      </div>
    </MainLayout>
  );
}
