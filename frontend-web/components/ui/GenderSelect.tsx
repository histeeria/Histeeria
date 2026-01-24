'use client';

import { useState, useEffect } from 'react';

interface GenderSelectProps {
  value: string | null;
  customValue: string | null;
  onChange: (gender: string | null, customValue: string | null) => void;
  disabled?: boolean;
}

const GENDER_OPTIONS = [
  { value: '', label: 'Select gender (optional)' },
  { value: 'male', label: 'Male' },
  { value: 'female', label: 'Female' },
  { value: 'non-binary', label: 'Non-binary' },
  { value: 'prefer-not-to-say', label: 'Prefer not to say' },
  { value: 'custom', label: 'Custom' },
];

export default function GenderSelect({ value, customValue, onChange, disabled }: GenderSelectProps) {
  const [selectedGender, setSelectedGender] = useState<string>(value || '');
  const [customText, setCustomText] = useState<string>(customValue || '');

  useEffect(() => {
    setSelectedGender(value || '');
    setCustomText(customValue || '');
  }, [value, customValue]);

  const handleGenderChange = (newGender: string) => {
    setSelectedGender(newGender);
    if (newGender === 'custom') {
      onChange(newGender, customText || '');
    } else {
      onChange(newGender || null, null);
    }
  };

  const handleCustomTextChange = (newText: string) => {
    setCustomText(newText);
    onChange('custom', newText || null);
  };

  return (
    <div className="space-y-2">
      <select
        value={selectedGender}
        onChange={(e) => handleGenderChange(e.target.value)}
        disabled={disabled}
        className="w-full px-4 py-3 rounded-xl border border-neutral-200 dark:border-neutral-700 bg-white dark:bg-neutral-900 text-neutral-900 dark:text-neutral-100 focus:outline-none focus:ring-2 focus:ring-brand-purple-500 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {GENDER_OPTIONS.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>

      {selectedGender === 'custom' && (
        <input
          type="text"
          value={customText}
          onChange={(e) => handleCustomTextChange(e.target.value)}
          placeholder="Enter your gender identity"
          disabled={disabled}
          maxLength={50}
          className="w-full px-4 py-3 rounded-xl border border-neutral-200 dark:border-neutral-700 bg-white dark:bg-neutral-900 text-neutral-900 dark:text-neutral-100 placeholder-neutral-400 dark:placeholder-neutral-500 focus:outline-none focus:ring-2 focus:ring-brand-purple-500 disabled:opacity-50 disabled:cursor-not-allowed"
        />
      )}
    </div>
  );
}

