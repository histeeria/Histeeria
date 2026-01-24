'use client';

import { useEffect, useState } from 'react';
import { X, CheckCircle, XCircle, Info, AlertTriangle } from 'lucide-react';

export type ToastType = 'success' | 'error' | 'info' | 'warning';

interface Toast {
  id: string;
  message: string;
  type: ToastType;
  duration?: number;
}

let toastQueue: Toast[] = [];
let listeners: Array<(toasts: Toast[]) => void> = [];
let toastCounter = 0;

const generateToastId = () => {
  toastCounter++;
  return `${Date.now()}-${toastCounter}`;
};

export const toast = {
  success: (message: string, duration = 3000) => {
    addToast({ id: generateToastId(), message, type: 'success', duration });
  },
  error: (message: string, duration = 4000) => {
    addToast({ id: generateToastId(), message, type: 'error', duration });
  },
  info: (message: string, duration = 3000) => {
    addToast({ id: generateToastId(), message, type: 'info', duration });
  },
  warning: (message: string, duration = 3500) => {
    addToast({ id: generateToastId(), message, type: 'warning', duration });
  },
};

function addToast(toast: Toast) {
  toastQueue = [...toastQueue, toast];
  notifyListeners();

  // Auto-remove after duration
  if (toast.duration) {
    setTimeout(() => {
      removeToast(toast.id);
    }, toast.duration);
  }
}

function removeToast(id: string) {
  toastQueue = toastQueue.filter((t) => t.id !== id);
  notifyListeners();
}

function notifyListeners() {
  listeners.forEach((listener) => listener([...toastQueue]));
}

export function ToastContainer() {
  const [toasts, setToasts] = useState<Toast[]>([]);

  useEffect(() => {
    listeners.push(setToasts);
    return () => {
      listeners = listeners.filter((l) => l !== setToasts);
    };
  }, []);

  const getIcon = (type: ToastType) => {
    switch (type) {
      case 'success':
        return <CheckCircle className="w-5 h-5 text-green-500" />;
      case 'error':
        return <XCircle className="w-5 h-5 text-red-500" />;
      case 'warning':
        return <AlertTriangle className="w-5 h-5 text-yellow-500" />;
      case 'info':
        return <Info className="w-5 h-5 text-blue-500" />;
    }
  };

  const getStyles = (type: ToastType) => {
    switch (type) {
      case 'success':
        return 'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800';
      case 'error':
        return 'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800';
      case 'warning':
        return 'bg-yellow-50 dark:bg-yellow-900/20 border-yellow-200 dark:border-yellow-800';
      case 'info':
        return 'bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800';
    }
  };

  return (
    <div className="fixed top-4 right-4 z-[200] flex flex-col gap-2 pointer-events-none">
      {toasts.map((toast) => (
        <div
          key={toast.id}
          className={`pointer-events-auto flex items-center gap-3 px-4 py-3 rounded-lg border shadow-lg backdrop-blur-sm animate-in slide-in-from-right duration-300 ${getStyles(
            toast.type
          )}`}
        >
          {getIcon(toast.type)}
          <p className="text-sm font-medium text-gray-900 dark:text-white flex-1">
            {toast.message}
          </p>
          <button
            onClick={() => removeToast(toast.id)}
            className="p-1 hover:bg-black/10 dark:hover:bg-white/10 rounded transition-colors"
          >
            <X className="w-4 h-4 text-gray-600 dark:text-gray-400" />
          </button>
        </div>
      ))}
    </div>
  );
}

