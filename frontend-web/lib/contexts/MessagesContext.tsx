'use client';

import { createContext, useContext, useState, ReactNode } from 'react';

interface MessagesContextType {
  isMessagesOpen: boolean;
  selectedUserId: string | null;
  openMessages: (userId?: string) => void;
  closeMessages: () => void;
}

const MessagesContext = createContext<MessagesContextType | undefined>(undefined);

export function MessagesProvider({ children }: { children: ReactNode }) {
  const [isMessagesOpen, setIsMessagesOpen] = useState(false);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);

  const openMessages = (userId?: string) => {
    setSelectedUserId(userId || null);
    setIsMessagesOpen(true);
  };

  const closeMessages = () => {
    setIsMessagesOpen(false);
    setSelectedUserId(null);
  };

  return (
    <MessagesContext.Provider value={{ isMessagesOpen, selectedUserId, openMessages, closeMessages }}>
      {children}
    </MessagesContext.Provider>
  );
}

export function useMessages() {
  const context = useContext(MessagesContext);
  if (!context) {
    throw new Error('useMessages must be used within MessagesProvider');
  }
  return context;
}

