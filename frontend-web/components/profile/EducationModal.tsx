'use client';

/**
 * Education Add/Edit Modal
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 */

import { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';

interface Education {
  id?: string;
  school_name: string;
  degree?: string | null;
  field_of_study?: string | null;
  start_date: string;
  end_date?: string | null;
  is_current: boolean;
  description?: string | null;
}

interface EducationModalProps {
  isOpen: boolean;
  education?: Education | null;
  onClose: () => void;
  onSave: (data: any) => Promise<void>;
}

export default function EducationModal({ isOpen, education, onClose, onSave }: EducationModalProps) {
  const [formData, setFormData] = useState({
    school_name: '',
    degree: '',
    field_of_study: '',
    start_date: '',
    end_date: '',
    is_current: false,
    description: '',
  });
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (isOpen) {
      if (education) {
        setFormData({
          school_name: education.school_name,
          degree: education.degree || '',
          field_of_study: education.field_of_study || '',
          start_date: education.start_date.split('T')[0],
          end_date: education.end_date ? education.end_date.split('T')[0] : '',
          is_current: education.is_current,
          description: education.description || '',
        });
      } else {
        setFormData({
          school_name: '',
          degree: '',
          field_of_study: '',
          start_date: '',
          end_date: '',
          is_current: false,
          description: '',
        });
      }
      setError(null);
    }
  }, [isOpen, education]);

  const handleSave = async () => {
    setIsLoading(true);
    setError(null);

    try {
      await onSave(formData);
      onClose();
    } catch (err: any) {
      setError(err.message || 'Failed to save');
    } finally {
      setIsLoading(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
      <div className="w-full max-w-2xl bg-white dark:bg-neutral-900 rounded-2xl shadow-2xl overflow-hidden max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between p-4 md:p-6 border-b border-neutral-200 dark:border-neutral-800">
          <h2 className="text-lg md:text-xl font-semibold text-neutral-900 dark:text-white">
            {education ? 'Edit Education' : 'Add Education'}
          </h2>
          <button
            onClick={onClose}
            disabled={isLoading}
            className="p-1.5 md:p-2 rounded-lg hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content - Scrollable */}
        <div className="flex-1 overflow-y-auto p-4 md:p-6 space-y-3 md:space-y-4">
          <Input
            label="School Name"
            value={formData.school_name}
            onChange={(e) => setFormData({ ...formData, school_name: e.target.value })}
            placeholder="e.g., Stanford University"
            disabled={isLoading}
            labelBg="bg-white dark:bg-neutral-900"
          />

          <Input
            label="Degree (optional)"
            value={formData.degree}
            onChange={(e) => setFormData({ ...formData, degree: e.target.value })}
            placeholder="e.g., Bachelor's, Master's, PhD"
            disabled={isLoading}
            labelBg="bg-white dark:bg-neutral-900"
          />

          <Input
            label="Field of Study (optional)"
            value={formData.field_of_study}
            onChange={(e) => setFormData({ ...formData, field_of_study: e.target.value })}
            placeholder="e.g., Computer Science"
            disabled={isLoading}
            labelBg="bg-white dark:bg-neutral-900"
          />

          <div className="grid grid-cols-2 gap-4">
            <Input
              label="Start Date"
              type="date"
              value={formData.start_date}
              onChange={(e) => setFormData({ ...formData, start_date: e.target.value })}
              disabled={isLoading}
              labelBg="bg-white dark:bg-neutral-900"
            />

            <Input
              label="End Date"
              type="date"
              value={formData.end_date}
              onChange={(e) => setFormData({ ...formData, end_date: e.target.value })}
              disabled={isLoading || formData.is_current}
              labelBg="bg-white dark:bg-neutral-900"
            />
          </div>

          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={formData.is_current}
              onChange={(e) => setFormData({ ...formData, is_current: e.target.checked, end_date: e.target.checked ? '' : formData.end_date })}
              disabled={isLoading}
              className="w-4 h-4 md:w-5 md:h-5 rounded text-brand-purple-600"
            />
            <span className="text-xs md:text-sm text-neutral-700 dark:text-neutral-300">
              I currently study here
            </span>
          </label>

          <div>
            <label className="block text-xs md:text-sm font-medium text-neutral-700 dark:text-neutral-300 mb-1.5 md:mb-2">
              Description (optional)
            </label>
            <textarea
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              placeholder="Describe your courses, research, achievements..."
              maxLength={200}
              rows={3}
              disabled={isLoading}
              className="w-full px-3 py-2.5 md:px-4 md:py-3 text-sm md:text-base rounded-xl border border-neutral-200 dark:border-neutral-800 bg-transparent text-neutral-900 dark:text-neutral-100 placeholder-neutral-400 dark:placeholder-neutral-500 focus:outline-none focus:ring-2 focus:ring-brand-purple-500 focus:border-brand-purple-500 resize-none"
            />
            <div className="mt-1 text-xs text-neutral-500 text-right">
              {formData.description.length} / 200
            </div>
          </div>

          {error && (
            <div className="p-3 bg-red-50 dark:bg-red-900/20 text-red-800 dark:text-red-200 rounded-lg text-sm">
              {error}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-2 p-4 md:p-6 border-t border-neutral-200 dark:border-neutral-800">
          <button
            onClick={onClose}
            disabled={isLoading}
            className="px-4 py-2 md:px-5 md:py-2.5 text-sm font-medium text-neutral-700 dark:text-neutral-300 hover:bg-neutral-100 dark:hover:bg-neutral-800 rounded-lg transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            disabled={isLoading}
            className="px-4 py-2 md:px-5 md:py-2.5 text-sm font-semibold bg-purple-600 hover:bg-purple-700 text-white rounded-lg transition-colors disabled:opacity-50"
          >
            {isLoading ? 'Saving...' : education ? 'Save' : 'Add'}
          </button>
        </div>
      </div>
    </div>
  );
}

