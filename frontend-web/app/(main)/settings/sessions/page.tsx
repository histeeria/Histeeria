'use client';

/**
 * Active Sessions Settings Page
 * Instagram-style: transparent, full-width, no borders
 */

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { MainLayout } from '@/components/layout/MainLayout';
import { Button } from '@/components/ui/Button';
import { Badge } from '@/components/ui/Badge';
import { ArrowLeft, Smartphone } from 'lucide-react';

export default function SessionsSettingsPage() {
  const router = useRouter();
  const [sessions, setSessions] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState('');
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  useEffect(() => {
    fetchSessions();
  }, []);

  const fetchSessions = async () => {
    try {
      setLoading(true);
      const token = localStorage.getItem('token');
      const response = await fetch('/api/proxy/v1/account/sessions', {
        headers: { 'Authorization': `Bearer ${token}` },
      });

      if (response.ok) {
        const data = await response.json();
        setSessions(data.sessions || []);
      } else {
        setMessage('Failed to fetch sessions');
      }
    } catch (error) {
      setMessage('Network error');
    } finally {
      setLoading(false);
    }
  };

  const handleRevokeSession = async (sessionId: string) => {
    if (!confirm('Are you sure you want to logout from this device?')) return;

    setActionLoading(sessionId);
    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`/api/proxy/v1/account/sessions/${sessionId}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` },
      });

      if (response.ok) {
        setMessage('Session revoked successfully');
        fetchSessions();
      } else {
        const data = await response.json();
        setMessage(data.message || 'Failed to revoke session');
      }
    } catch (error) {
      setMessage('Network error');
    } finally {
      setActionLoading(null);
    }
  };

  const handleLogoutAll = async () => {
    if (!confirm('Logout from all devices? You will be logged out.')) return;

    setActionLoading('all');
    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/proxy/v1/account/logout-all', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` },
      });

      if (response.ok) {
        localStorage.removeItem('token');
        window.location.href = '/auth';
      } else {
        const data = await response.json();
        setMessage(data.message || 'Failed to logout');
      }
    } catch (error) {
      setMessage('Network error');
    } finally {
      setActionLoading(null);
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
              Active Sessions
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
            <div className="px-4 py-6 space-y-4">
              <h3 className="text-base font-semibold text-neutral-900 dark:text-neutral-50">
                Active Sessions ({sessions.length})
              </h3>
              
              {sessions.length === 0 ? (
                <p className="text-neutral-600 dark:text-neutral-400 text-center py-8">
                  No active sessions found
                </p>
              ) : (
                <div className="space-y-4">
                  {sessions.map((session, index) => (
                    <div key={session.id}>
                      <div className="flex items-start justify-between py-3">
                        <div className="flex items-start gap-3">
                          <Smartphone className="w-5 h-5 text-neutral-500 mt-1" />
                          <div>
                            <div className="flex items-center gap-2 mb-1">
                              <p className="font-medium text-neutral-900 dark:text-neutral-50">
                                {session.device_info || 'Unknown Device'}
                              </p>
                              {session.is_current && (
                                <Badge variant="success" size="sm">Current</Badge>
                              )}
                            </div>
                            <p className="text-sm text-neutral-600 dark:text-neutral-400">
                              {session.ip_address || 'Unknown IP'}
                            </p>
                            <p className="text-xs text-neutral-500 dark:text-neutral-400 mt-1">
                              Last active: {new Date(session.created_at).toLocaleString()}
                            </p>
                          </div>
                        </div>
                        {!session.is_current && (
                          <Button 
                            variant="ghost" 
                            size="sm"
                            onClick={() => handleRevokeSession(session.id)}
                            isLoading={actionLoading === session.id}
                          >
                            Revoke
                          </Button>
                        )}
                      </div>
                      {index < sessions.length - 1 && (
                        <div className="h-px bg-neutral-200 dark:bg-neutral-800 ml-8" />
                      )}
                    </div>
                  ))}
                  
                  <div className="pt-4 border-t border-neutral-200 dark:border-neutral-800 mt-4">
                    <Button 
                      variant="danger" 
                      onClick={handleLogoutAll}
                      isLoading={actionLoading === 'all'}
                      className="w-full"
                    >
                      Logout All Devices
                    </Button>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </MainLayout>
  );
}
