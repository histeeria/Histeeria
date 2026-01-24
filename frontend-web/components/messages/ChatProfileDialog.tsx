'use client';

import { useState, useEffect } from 'react';
import { X, ExternalLink, Image as ImageIcon, FileText, Mic, Link as LinkIcon, Bell, BellOff, Eye, EyeOff, Ban, AlertTriangle, Lock, ChevronRight } from 'lucide-react';
import { messagesAPI, Message } from '@/lib/api/messages';
import { Avatar } from '../ui/Avatar';
import { toast } from '../ui/Toast';
import { ConfirmDialog } from '../ui/ConfirmDialog';
import { MediaViewer } from './MediaViewer';

interface ChatProfileDialogProps {
  isOpen: boolean;
  conversation: any;
  onClose: () => void;
  onViewProfile: () => void;
}

type MediaTab = 'photos' | 'documents' | 'audios' | 'links';

export function ChatProfileDialog({
  isOpen,
  conversation,
  onClose,
  onViewProfile,
}: ChatProfileDialogProps) {
  const [activeTab, setActiveTab] = useState<MediaTab>('photos');
  const [mediaMessages, setMediaMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(false);
  const [isMuted, setIsMuted] = useState(false);
  const [mediaAutoDownload, setMediaAutoDownload] = useState(true);
  const [showBlockConfirm, setShowBlockConfirm] = useState(false);
  const [showReportConfirm, setShowReportConfirm] = useState(false);
  const [viewingMedia, setViewingMedia] = useState<Message | null>(null);

  const otherUser = conversation?.other_user;

  useEffect(() => {
    if (isOpen && conversation) {
      loadChatMedia();
    }
  }, [isOpen, conversation, activeTab]);

  const loadChatMedia = async () => {
    try {
      setLoading(true);
      const response = await messagesAPI.getMessages(conversation.id, 100, 0);
      if (response.success) {
        setMediaMessages(response.messages);
      }
    } catch (error) {
      console.error('Failed to load media:', error);
    } finally {
      setLoading(false);
    }
  };

  const getMediaByType = (type: string) => {
    return mediaMessages.filter(msg => msg.message_type === type);
  };

  const getLinks = () => {
    // Extract links from text messages (basic implementation)
    return mediaMessages.filter(msg => 
      msg.message_type === 'text' && 
      (msg.content.includes('http://') || msg.content.includes('https://'))
    );
  };

  const handleMuteToggle = () => {
    setIsMuted(!isMuted);
    toast.success(isMuted ? 'Chat unmuted' : 'Chat muted');
  };

  const handleMediaVisibilityToggle = () => {
    setMediaAutoDownload(!mediaAutoDownload);
    toast.success(mediaAutoDownload ? 'Media auto-download disabled' : 'Media auto-download enabled');
  };

  const handleBlock = () => {
    setShowBlockConfirm(true);
  };

  const confirmBlock = () => {
    // TODO: Implement block API
    toast.success('User blocked');
    setShowBlockConfirm(false);
    onClose();
  };

  const handleReport = () => {
    setShowReportConfirm(true);
  };

  const confirmReport = () => {
    // TODO: Implement report API
    toast.success('User reported');
    setShowReportConfirm(false);
  };

  if (!isOpen || !otherUser) return null;

  const photos = getMediaByType('image');
  const documents = getMediaByType('file');
  const audios = getMediaByType('audio');
  const links = getLinks();

  const mediaTabs = [
    { id: 'photos' as MediaTab, label: 'Photos', count: photos.length, icon: ImageIcon },
    { id: 'documents' as MediaTab, label: 'Docs', count: documents.length, icon: FileText },
    { id: 'audios' as MediaTab, label: 'Audio', count: audios.length, icon: Mic },
    { id: 'links' as MediaTab, label: 'Links', count: links.length, icon: LinkIcon },
  ];

  const getActiveMedia = () => {
    switch (activeTab) {
      case 'photos': return photos;
      case 'documents': return documents;
      case 'audios': return audios;
      case 'links': return links;
      default: return [];
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div
        className="bg-white dark:bg-gray-800 rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-gray-200 dark:border-gray-700">
          <h3 className="text-lg font-bold text-gray-900 dark:text-white">
            Contact Info
          </h3>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
          </button>
        </div>

        {/* Scrollable Content */}
        <div className="flex-1 overflow-y-auto">
          {/* Profile Overview */}
          <div className="flex flex-col items-center p-6 border-b border-gray-200 dark:border-gray-700">
            <Avatar
              src={otherUser.profile_picture || otherUser.avatar_url}
              alt={otherUser.display_name}
              size="2xl"
              showOnline={true}
              isOnline={conversation.is_online}
            />
            <h2 className="text-xl font-bold text-gray-900 dark:text-white mt-4">
              {otherUser.display_name || otherUser.username}
            </h2>
            <p className="text-sm text-gray-500 dark:text-gray-400">
              @{otherUser.username}
            </p>
            {otherUser.bio && (
              <p className="text-sm text-gray-700 dark:text-gray-300 mt-2 text-center max-w-xs">
                {otherUser.bio}
              </p>
            )}
            
            {/* View Profile Button */}
            <button
              onClick={() => {
                onViewProfile();
                onClose();
              }}
              className="mt-4 flex items-center gap-2 px-6 py-2.5 bg-purple-600 hover:bg-purple-700 text-white rounded-full transition-colors font-medium"
            >
              View Profile
              <ExternalLink className="w-4 h-4" />
            </button>
          </div>

          {/* Chat Controls */}
          <div className="border-b border-gray-200 dark:border-gray-700">
            <div className="p-4 space-y-2">
              <h4 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">
                Chat Controls
              </h4>

              {/* Mute/Unmute */}
              <button
                onClick={handleMuteToggle}
                className="w-full flex items-center justify-between px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-700/50 rounded-lg transition-colors"
              >
                <div className="flex items-center gap-3">
                  {isMuted ? (
                    <BellOff className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                  ) : (
                    <Bell className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                  )}
                  <span className="text-gray-900 dark:text-white font-medium">
                    {isMuted ? 'Unmute notifications' : 'Mute notifications'}
                  </span>
                </div>
                <ChevronRight className="w-4 h-4 text-gray-400" />
              </button>

              {/* Media Visibility */}
              <button
                onClick={handleMediaVisibilityToggle}
                className="w-full flex items-center justify-between px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-700/50 rounded-lg transition-colors"
              >
                <div className="flex items-center gap-3">
                  {mediaAutoDownload ? (
                    <Eye className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                  ) : (
                    <EyeOff className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                  )}
                  <span className="text-gray-900 dark:text-white font-medium">
                    Media auto-download
                  </span>
                </div>
                <span className={`text-sm ${
                  mediaAutoDownload 
                    ? 'text-green-600 dark:text-green-400' 
                    : 'text-gray-500 dark:text-gray-400'
                }`}>
                  {mediaAutoDownload ? 'On' : 'Off'}
                </span>
              </button>
            </div>
          </div>

          {/* Profile Actions */}
          <div className="border-b border-gray-200 dark:border-gray-700">
            <div className="p-4 space-y-2">
              <h4 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">
                Profile Actions
              </h4>

              {/* Block/Unblock */}
              <button
                onClick={handleBlock}
                className="w-full flex items-center justify-between px-4 py-3 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors group"
              >
                <div className="flex items-center gap-3">
                  <Ban className="w-5 h-5 text-red-600 dark:text-red-400" />
                  <span className="text-red-600 dark:text-red-400 font-medium">
                    Block user
                  </span>
                </div>
                <ChevronRight className="w-4 h-4 text-red-400 opacity-0 group-hover:opacity-100 transition-opacity" />
              </button>

              {/* Report */}
              <button
                onClick={handleReport}
                className="w-full flex items-center justify-between px-4 py-3 hover:bg-orange-50 dark:hover:bg-orange-900/20 rounded-lg transition-colors group"
              >
                <div className="flex items-center gap-3">
                  <AlertTriangle className="w-5 h-5 text-orange-600 dark:text-orange-400" />
                  <span className="text-orange-600 dark:text-orange-400 font-medium">
                    Report user
                  </span>
                </div>
                <ChevronRight className="w-4 h-4 text-orange-400 opacity-0 group-hover:opacity-100 transition-opacity" />
              </button>
            </div>
          </div>

          {/* Encryption Info */}
          <div className="p-4 border-b border-gray-200 dark:border-gray-700">
            <button
              onClick={() => toast.info('Privacy policy coming soon!')}
              className="w-full flex items-center justify-between px-4 py-3 bg-green-50 dark:bg-green-900/20 hover:bg-green-100 dark:hover:bg-green-900/30 rounded-lg transition-colors"
            >
              <div className="flex items-center gap-3">
                <Lock className="w-5 h-5 text-green-600 dark:text-green-400" />
                <div className="text-left">
                  <p className="text-sm font-medium text-green-700 dark:text-green-300">
                    End-to-end encryption
                  </p>
                  <p className="text-xs text-green-600/70 dark:text-green-400/70">
                    Messages are secure
                  </p>
                </div>
              </div>
              <ChevronRight className="w-4 h-4 text-green-600 dark:text-green-400" />
            </button>
          </div>

          {/* Chat Media Section - At the bottom with slider */}
          <div className="p-4 pb-6">
            <h4 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">
              Chat Media, Docs & Links
            </h4>

            {/* Media Tabs - Horizontal Scrollable */}
            <div className="flex gap-2 overflow-x-auto pb-3 scrollbar-hide">
              {mediaTabs.map((tab) => (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`flex items-center gap-2 px-4 py-2 rounded-full transition-all whitespace-nowrap flex-shrink-0 ${
                    activeTab === tab.id
                      ? 'bg-purple-600 text-white shadow-md'
                      : 'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600'
                  }`}
                >
                  <tab.icon className="w-4 h-4" />
                  <span className="text-sm font-medium">{tab.label}</span>
                  {tab.count > 0 && (
                    <span className={`text-xs font-bold px-1.5 py-0.5 rounded-full ${
                      activeTab === tab.id 
                        ? 'bg-purple-500 text-white' 
                        : 'bg-gray-200 dark:bg-gray-600 text-gray-600 dark:text-gray-300'
                    }`}>
                      {tab.count}
                    </span>
                  )}
                </button>
              ))}
            </div>

            {/* Media Container - Larger with horizontal scroll */}
            <div className="mt-4 bg-gray-50 dark:bg-gray-900/50 rounded-xl p-3 min-h-[200px]">
              {loading ? (
                <div className="flex items-center justify-center h-40">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-purple-600"></div>
                </div>
              ) : getActiveMedia().length === 0 ? (
                <div className="flex flex-col items-center justify-center h-40 text-gray-500 dark:text-gray-400">
                  <div className="mb-2">
                    {mediaTabs.find(t => t.id === activeTab)?.icon && (
                      <div className="p-3 bg-gray-200 dark:bg-gray-700 rounded-full">
                        {(() => {
                          const IconComponent = mediaTabs.find(t => t.id === activeTab)!.icon;
                          return <IconComponent className="w-8 h-8" />;
                        })()}
                      </div>
                    )}
                  </div>
                  <p className="text-sm font-medium">No {activeTab} shared yet</p>
                  <p className="text-xs mt-1">Media will appear here</p>
                </div>
              ) : (
                <>
                  {/* Horizontal Scrollable Grid - Instagram Style */}
                  <div className="overflow-x-auto scrollbar-hide">
                    <div className="flex gap-2 pb-2">
                      {getActiveMedia().map((msg) => (
                        <div
                          key={msg.id}
                          className="w-32 h-32 bg-gray-200 dark:bg-gray-700 rounded-lg overflow-hidden cursor-pointer hover:opacity-80 hover:scale-105 transition-all flex-shrink-0 shadow-sm"
                          onClick={() => setViewingMedia(msg)}
                        >
                          {msg.message_type === 'image' && msg.attachment_url && (
                            <img
                              src={msg.attachment_url}
                              alt="Media"
                              className="w-full h-full object-cover"
                            />
                          )}
                          {msg.message_type === 'audio' && (
                            <div className="w-full h-full flex flex-col items-center justify-center gap-2 p-3">
                              <Mic className="w-8 h-8 text-gray-500 dark:text-gray-400" />
                              <span className="text-xs text-gray-600 dark:text-gray-400 text-center truncate w-full">
                                Voice
                              </span>
                            </div>
                          )}
                          {msg.message_type === 'file' && (
                            <div className="w-full h-full flex flex-col items-center justify-center gap-2 p-3">
                              <FileText className="w-8 h-8 text-gray-500 dark:text-gray-400" />
                              <span className="text-xs text-gray-600 dark:text-gray-400 text-center truncate w-full">
                                {msg.attachment_name || 'File'}
                              </span>
                            </div>
                          )}
                          {activeTab === 'links' && (
                            <div className="w-full h-full flex flex-col items-center justify-center gap-2 p-3">
                              <LinkIcon className="w-8 h-8 text-blue-500 dark:text-blue-400" />
                              <span className="text-xs text-gray-600 dark:text-gray-400 text-center truncate w-full px-2">
                                {msg.content.substring(0, 30)}...
                              </span>
                            </div>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Show "View All" if more than 10 items */}
                  {getActiveMedia().length > 10 && (
                    <button
                      onClick={() => toast.info('View all feature coming soon!')}
                      className="mt-3 w-full py-2 text-sm text-purple-600 dark:text-purple-400 hover:bg-purple-50 dark:hover:bg-purple-900/20 rounded-lg transition-colors font-medium"
                    >
                      View all {getActiveMedia().length} {activeTab}
                    </button>
                  )}
                </>
              )}
            </div>
          </div>
        </div>

        {/* Block Confirmation */}
        <ConfirmDialog
          isOpen={showBlockConfirm}
          title="Block User?"
          message={`Block ${otherUser.display_name || otherUser.username}? They won't be able to message you anymore.`}
          confirmText="Block"
          cancelText="Cancel"
          variant="danger"
          onConfirm={confirmBlock}
          onCancel={() => setShowBlockConfirm(false)}
        />

        {/* Report Confirmation */}
        <ConfirmDialog
          isOpen={showReportConfirm}
          title="Report User?"
          message={`Report ${otherUser.display_name || otherUser.username} for violating community guidelines? Our team will review this report.`}
          confirmText="Report"
          cancelText="Cancel"
          variant="warning"
          onConfirm={confirmReport}
          onCancel={() => setShowReportConfirm(false)}
        />

        {/* Media Viewer - WhatsApp Style */}
        {viewingMedia && (
          <MediaViewer
            isOpen={true}
            message={viewingMedia}
            allMedia={getActiveMedia()}
            onClose={() => setViewingMedia(null)}
          />
        )}
      </div>
    </div>
  );
}

