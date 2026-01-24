'use client';

/**
 * Experience Add/Edit Modal
 * Created by: Hamza Hafeez - Founder & CEO of Upvista
 */

import { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';

interface Experience {
  id?: string;
  company_name: string;
  title: string;
  employment_type?: string | null;
  start_date: string;
  end_date?: string | null;
  is_current: boolean;
  description?: string | null;
  is_public: boolean;
}

interface ExperienceModalProps {
  isOpen: boolean;
  experience?: Experience | null;
  onClose: () => void;
  onSave: (data: any) => Promise<void>;
}

const EMPLOYMENT_TYPES = [
  { value: '', label: 'Select type (optional)' },
  { value: 'full-time', label: 'Full-time' },
  { value: 'part-time', label: 'Part-time' },
  { value: 'contract', label: 'Contract' },
  { value: 'internship', label: 'Internship' },
  { value: 'freelance', label: 'Freelance' },
  { value: 'self-employed', label: 'Self-employed' },
];

export default function ExperienceModal({ isOpen, experience, onClose, onSave }: ExperienceModalProps) {
  const [formData, setFormData] = useState({
    company_name: '',
    title: '',
    employment_type: '',
    start_date: '',
    end_date: '',
    is_current: false,
    description: '',
    is_public: true,
  });
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (isOpen) {
      if (experience) {
        setFormData({
          company_name: experience.company_name,
          title: experience.title,
          employment_type: experience.employment_type || '',
          start_date: experience.start_date.split('T')[0],
          end_date: experience.end_date ? experience.end_date.split('T')[0] : '',
          is_current: experience.is_current,
          description: experience.description || '',
          is_public: experience.is_public,
        });
      } else {
        setFormData({
          company_name: '',
          title: '',
          employment_type: '',
          start_date: '',
          end_date: '',
          is_current: false,
          description: '',
          is_public: true,
        });
      }
      setError(null);
    }
  }, [isOpen, experience]);

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
            {experience ? 'Edit Experience' : 'Add Experience'}
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
            label="Company Name"
            value={formData.company_name}
            onChange={(e) => setFormData({ ...formData, company_name: e.target.value })}
            placeholder="e.g., Upvista"
            disabled={isLoading}
            labelBg="bg-white dark:bg-neutral-900"
          />

          <Input
            label="Title"
            value={formData.title}
            onChange={(e) => setFormData({ ...formData, title: e.target.value })}
            placeholder="e.g., Software Engineer"
            disabled={isLoading}
            labelBg="bg-white dark:bg-neutral-900"
          />

          <div>
            <label className="block text-xs md:text-sm font-medium text-neutral-700 dark:text-neutral-300 mb-1.5 md:mb-2">
              Employment Type
            </label>
            <select
              value={formData.employment_type}
              onChange={(e) => setFormData({ ...formData, employment_type: e.target.value })}
              disabled={isLoading}
              className="w-full px-3 py-2.5 md:px-4 md:py-3 text-sm md:text-base rounded-xl border-2 border-neutral-200 dark:border-neutral-700 bg-white dark:bg-neutral-900 text-neutral-900 dark:text-neutral-100 focus:outline-none focus:ring-2 focus:ring-brand-purple-500"
            >
              {EMPLOYMENT_TYPES.map((type) => (
                <option key={type.value} value={type.value}>
                  {type.label}
                </option>
              ))}
            </select>
          </div>

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
              I currently work here
            </span>
          </label>

          <div>
            <label className="block text-xs md:text-sm font-medium text-neutral-700 dark:text-neutral-300 mb-1.5 md:mb-2">
              Description (optional)
            </label>
            <textarea
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              placeholder="Describe your role and achievements..."
              maxLength={200}
              rows={3}
              disabled={isLoading}
              className="w-full px-3 py-2.5 md:px-4 md:py-3 text-sm md:text-base rounded-lg border border-neutral-200 dark:border-neutral-800 bg-transparent text-neutral-900 dark:text-neutral-100 placeholder-neutral-400 dark:placeholder-neutral-500 focus:outline-none focus:ring-2 focus:ring-brand-purple-500 focus:border-brand-purple-500 resize-none"
            />
            <div className="mt-1 text-xs text-neutral-500 text-right">
              {formData.description.length} / 200
            </div>
          </div>

          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={formData.is_public}
              onChange={(e) => setFormData({ ...formData, is_public: e.target.checked })}
              disabled={isLoading}
              className="w-4 h-4 md:w-5 md:h-5 rounded text-brand-purple-600"
            />
            <span className="text-xs md:text-sm text-neutral-700 dark:text-neutral-300">
              Make this experience public (uncheck to show only to recruiters)
            </span>
          </label>

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
            {isLoading ? 'Saving...' : experience ? 'Save' : 'Add'}
          </button>
        </div>
      </div>
    </div>
  );
}

