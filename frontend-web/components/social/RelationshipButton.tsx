'use client';

/**
 * RelationshipButton Component
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 * 
 * Split button with dropdown for Follow/Connect/Collaborate
 */

import { useState, useEffect, useRef } from 'react';
import { Button } from '@/components/ui/Button';
import { UserPlus, Check, Users, Sparkles, ChevronDown, Loader2 } from 'lucide-react';
import { relationshipAPI } from '@/lib/api';

// Global cache for relationship statuses
const statusCache = new Map<string, { status: RelationshipStatus; timestamp: number }>();
const inflightRequests = new Map<string, Promise<any>>();
const CACHE_DURATION = 30000; // 30 seconds

interface RelationshipButtonProps {
  targetUserId: string;
  initialStatus?: RelationshipStatus;
  onStatusChange?: (status: RelationshipStatus) => void;
}

interface RelationshipStatus {
  is_following: boolean;
  is_follower: boolean;
  is_connected: boolean;
  is_collaborating: boolean;
  has_pending: boolean;
  is_blocked: boolean;
}

type RelationshipTier = 'none' | 'following' | 'connected' | 'collaborating';

export default function RelationshipButton({ 
  targetUserId, 
  initialStatus,
  onStatusChange 
}: RelationshipButtonProps) {
  const [status, setStatus] = useState<RelationshipStatus>(
    initialStatus || {
      is_following: false,
      is_follower: false,
      is_connected: false,
      is_collaborating: false,
      has_pending: false,
      is_blocked: false,
    }
  );
  const [loading, setLoading] = useState(false);
  const [showDropdown, setShowDropdown] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setShowDropdown(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Fetch relationship status with caching and deduplication
  useEffect(() => {
    const fetchStatus = async () => {
      try {
        // Check cache first
        const cached = statusCache.get(targetUserId);
        if (cached && Date.now() - cached.timestamp < CACHE_DURATION) {
          console.log('[RelationshipButton] Using cached status for', targetUserId);
          setStatus(cached.status);
          return;
        }

        // Check if request is already in flight
        let request = inflightRequests.get(targetUserId);
        
        if (!request) {
          // Create new request
          request = relationshipAPI.getRelationshipStatus(targetUserId);
          inflightRequests.set(targetUserId, request);
        } else {
          console.log('[RelationshipButton] Waiting for inflight request');
        }

        const response = await request;
        
        if (response.success && response.status) {
          // Update cache
          statusCache.set(targetUserId, {
            status: response.status,
            timestamp: Date.now()
          });
          setStatus(response.status);
        }
      } catch (err) {
        console.error('Failed to fetch relationship status:', err);
      } finally {
        inflightRequests.delete(targetUserId);
      }
    };

    if (!initialStatus) {
      fetchStatus();
    }
  }, [targetUserId, initialStatus]);

  const getCurrentTier = (): RelationshipTier => {
    if (status.is_collaborating) return 'collaborating';
    if (status.is_connected) return 'connected';
    if (status.is_following) return 'following';
    return 'none';
  };

  const handleAction = async (action: 'follow' | 'connect' | 'collaborate' | 'unfollow' | 'disconnect') => {
    setLoading(true);
    setError(null);
    setShowDropdown(false);

    try {
      let response;

      switch (action) {
        case 'follow':
          response = await relationshipAPI.followUser(targetUserId);
          break;
        case 'connect':
          response = await relationshipAPI.connectWithUser(targetUserId);
          break;
        case 'collaborate':
          response = await relationshipAPI.collaborateWithUser(targetUserId);
          break;
        case 'unfollow':
          response = await relationshipAPI.removeRelationship(targetUserId, 'following');
          break;
        case 'disconnect':
          // If collaborating, remove collaboration; if just connected, remove connection
          if (status.is_collaborating) {
            response = await relationshipAPI.removeRelationship(targetUserId, 'collaborating');
          } else {
            response = await relationshipAPI.removeRelationship(targetUserId, 'connected');
          }
          break;
      }

      if (response && response.success) {
        // Clear cache for this user to force fresh data
        statusCache.delete(targetUserId);
        
        // Refresh status
        const statusResponse = await relationshipAPI.getRelationshipStatus(targetUserId);
        if (statusResponse.success && statusResponse.status) {
          // Update cache with new status
          statusCache.set(targetUserId, {
            status: statusResponse.status,
            timestamp: Date.now()
          });
          setStatus(statusResponse.status);
          if (onStatusChange) {
            onStatusChange(statusResponse.status);
          }
        }
      } else if (response && response.rate_limit) {
        // Rate limit error
        setError(response.message);
        setTimeout(() => setError(null), 5000);
      } else {
        setError(response?.message || 'Action failed');
        setTimeout(() => setError(null), 3000);
      }
    } catch (err: any) {
      console.error('Relationship action failed:', err);
      setError(err.message || 'Something went wrong');
      setTimeout(() => setError(null), 3000);
    } finally {
      setLoading(false);
    }
  };

  const tier = getCurrentTier();

  const buttonConfig = {
    none: {
      label: 'Follow',
      icon: <UserPlus className="w-4 h-4" />,
      className: 'border-brand-purple-600 text-brand-purple-600 hover:bg-brand-purple-50 dark:hover:bg-brand-purple-900/20',
      action: 'follow' as const,
    },
    following: {
      label: 'Following',
      icon: <Check className="w-4 h-4" />,
      className: 'bg-brand-purple-600 text-white hover:bg-brand-purple-700',
      action: null,
    },
    connected: {
      label: 'Connected',
      icon: <Users className="w-4 h-4" />,
      className: 'bg-blue-600 text-white hover:bg-blue-700',
      action: null,
    },
    collaborating: {
      label: 'Collaborating',
      icon: <Sparkles className="w-4 h-4" />,
      className: 'bg-gradient-to-r from-yellow-500 to-orange-500 text-white hover:from-yellow-600 hover:to-orange-600',
      action: null,
    },
  };

  const config = buttonConfig[tier];

  return (
    <div className="relative" ref={dropdownRef}>
      {/* Error Toast */}
      {error && (
        <div className="absolute top-full left-0 mt-2 w-64 bg-red-500 text-white text-sm px-4 py-2 rounded-lg shadow-lg z-50">
          {error}
        </div>
      )}

      {/* Split Button */}
      <div className="flex items-stretch">
        {/* Main Button */}
        <button
          onClick={() => config.action && handleAction(config.action)}
          disabled={loading || !config.action}
          className={`
            flex items-center gap-2 px-4 py-2 rounded-l-lg font-medium transition-colors
            border border-r-0 ${config.className}
            ${loading ? 'opacity-50 cursor-not-allowed' : ''}
            ${!config.action ? 'cursor-default' : ''}
          `}
        >
          {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : config.icon}
          <span>{config.label}</span>
        </button>

        {/* Dropdown Trigger */}
        <button
          onClick={() => setShowDropdown(!showDropdown)}
          disabled={loading}
          className={`
            flex items-center justify-center px-2 py-2 rounded-r-lg border transition-colors
            ${config.className}
            ${loading ? 'opacity-50 cursor-not-allowed' : ''}
          `}
        >
          <ChevronDown className="w-4 h-4" />
        </button>
      </div>

      {/* Dropdown Menu */}
      {showDropdown && (
        <div className="absolute top-full left-0 mt-2 w-56 bg-white dark:bg-neutral-800 rounded-lg shadow-lg border border-neutral-200 dark:border-neutral-700 py-2 z-50">
          {/* Always show all three tier options */}
          
          {/* Follow Option */}
          {status.is_following ? (
            <div className="px-4 py-2 text-neutral-500 dark:text-neutral-400 flex items-center gap-2">
              <Check className="w-4 h-4 text-brand-purple-600" />
              <span>Following</span>
            </div>
          ) : (
            <button
              onClick={() => handleAction('follow')}
              className="w-full px-4 py-2 text-left hover:bg-neutral-100 dark:hover:bg-neutral-700 flex items-center gap-2 text-neutral-900 dark:text-neutral-50"
            >
              <UserPlus className="w-4 h-4" />
              <span>Follow</span>
            </button>
          )}

          {/* Connect Option */}
          {status.is_connected ? (
            <div className="px-4 py-2 text-neutral-500 dark:text-neutral-400 flex items-center gap-2">
              <Check className="w-4 h-4 text-blue-600" />
              <span>Connected</span>
            </div>
          ) : (
            <button
              onClick={() => handleAction('connect')}
              className="w-full px-4 py-2 text-left hover:bg-neutral-100 dark:hover:bg-neutral-700 flex items-center gap-2 text-neutral-900 dark:text-neutral-50"
            >
              <Users className="w-4 h-4" />
              <span>Connect</span>
            </button>
          )}

          {/* Collaborate Option - Always show as active button */}
          {status.is_collaborating ? (
            <div className="px-4 py-2 text-neutral-500 dark:text-neutral-400 flex items-center gap-2">
              <Check className="w-4 h-4 text-yellow-600" />
              <span>Collaborating</span>
            </div>
          ) : (
            <button
              onClick={() => {
                if (!status.is_connected) {
                  // Show message that connection is required
                  setError('You must connect first before collaborating');
                  setTimeout(() => setError(null), 3000);
                  setShowDropdown(false);
                } else {
                  handleAction('collaborate');
                }
              }}
              className="w-full px-4 py-2 text-left hover:bg-neutral-100 dark:hover:bg-neutral-700 flex items-center gap-2 text-neutral-900 dark:text-neutral-50"
            >
              <Sparkles className="w-4 h-4" />
              <span>Collaborate</span>
            </button>
          )}

          {/* Separator */}
          {(status.is_following || status.is_connected || status.is_collaborating) && (
            <div className="my-1 border-t border-neutral-200 dark:border-neutral-700" />
          )}

          {/* Remove Options */}
          {status.is_collaborating && (
            <button
              onClick={() => handleAction('disconnect')}
              className="w-full px-4 py-2 text-left hover:bg-neutral-100 dark:hover:bg-neutral-700 text-red-600 dark:text-red-400"
            >
              End Collaboration
            </button>
          )}
          
          {status.is_connected && !status.is_collaborating && (
            <button
              onClick={() => handleAction('disconnect')}
              className="w-full px-4 py-2 text-left hover:bg-neutral-100 dark:hover:bg-neutral-700 text-red-600 dark:text-red-400"
            >
              Disconnect
            </button>
          )}

          {status.is_following && !status.is_connected && (
            <button
              onClick={() => handleAction('unfollow')}
              className="w-full px-4 py-2 text-left hover:bg-neutral-100 dark:hover:bg-neutral-700 text-red-600 dark:text-red-400"
            >
              Unfollow
            </button>
          )}
        </div>
      )}
    </div>
  );
}

