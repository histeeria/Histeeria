/**
 * Form Validation Utilities
 * Client-side validation for auth forms
 */

export interface ValidationError {
  field: string;
  message: string;
}

export interface ValidationResult {
  isValid: boolean;
  errors: ValidationError[];
}

/**
 * Validate email format
 */
export function validateEmail(email: string): string | null {
  if (!email.trim()) {
    return 'Email is required';
  }
  
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return 'Please enter a valid email address';
  }
  
  return null;
}

/**
 * Validate username
 */
export function validateUsername(username: string): string | null {
  if (!username.trim()) {
    return 'Username is required';
  }
  
  if (username.length < 3) {
    return 'Username must be at least 3 characters';
  }
  
  if (username.length > 20) {
    return 'Username must be less than 20 characters';
  }
  
  const usernameRegex = /^[a-zA-Z0-9_]+$/;
  if (!usernameRegex.test(username)) {
    return 'Username can only contain letters, numbers, and underscores';
  }
  
  return null;
}

/**
 * Validate password
 */
export function validatePassword(password: string, isSignUp = false): string | null {
  if (!password) {
    return 'Password is required';
  }
  
  if (isSignUp) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    if (!/(?=.*[a-z])/.test(password)) {
      return 'Password must contain at least one lowercase letter';
    }
    
    if (!/(?=.*[A-Z])/.test(password)) {
      return 'Password must contain at least one uppercase letter';
    }
  
    if (!/(?=.*\d)/.test(password)) {
      return 'Password must contain at least one number';
    }
  } else {
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
  }
  
  return null;
}

/**
 * Validate display name
 */
export function validateDisplayName(displayName: string): string | null {
  if (!displayName.trim()) {
    return 'Display name is required';
  }
  
  if (displayName.length < 2) {
    return 'Display name must be at least 2 characters';
  }
  
  if (displayName.length > 50) {
    return 'Display name must be less than 50 characters';
  }
  
  return null;
}

/**
 * Validate age
 */
export function validateAge(age: number): string | null {
  if (!age || age < 13) {
    return 'You must be at least 13 years old';
  }
  
  if (age > 120) {
    return 'Please enter a valid age';
  }
  
  return null;
}

/**
 * Validate sign-in form
 */
export function validateSignInForm(data: { email_or_username: string; password: string }): ValidationResult {
  const errors: ValidationError[] = [];
  
  // Check if it's an email or username
  const isEmail = data.email_or_username.includes('@');
  
  if (isEmail) {
    const emailError = validateEmail(data.email_or_username);
    if (emailError) {
      errors.push({ field: 'email_or_username', message: emailError });
    }
  } else {
    const usernameError = validateUsername(data.email_or_username);
    if (usernameError) {
      errors.push({ field: 'email_or_username', message: usernameError });
    }
  }
  
  const passwordError = validatePassword(data.password, false);
  if (passwordError) {
    errors.push({ field: 'password', message: passwordError });
  }
  
  return {
    isValid: errors.length === 0,
    errors,
  };
}

/**
 * Validate sign-up form
 */
export function validateSignUpForm(data: {
  email: string;
  password: string;
  display_name: string;
  username: string;
  age: number;
}): ValidationResult {
  const errors: ValidationError[] = [];
  
  const emailError = validateEmail(data.email);
  if (emailError) {
    errors.push({ field: 'email', message: emailError });
  }
  
  const usernameError = validateUsername(data.username);
  if (usernameError) {
    errors.push({ field: 'username', message: usernameError });
  }
  
  const displayNameError = validateDisplayName(data.display_name);
  if (displayNameError) {
    errors.push({ field: 'display_name', message: displayNameError });
  }
  
  const passwordError = validatePassword(data.password, true);
  if (passwordError) {
    errors.push({ field: 'password', message: passwordError });
  }
  
  const ageError = validateAge(data.age);
  if (ageError) {
    errors.push({ field: 'age', message: ageError });
  }
  
  return {
    isValid: errors.length === 0,
    errors,
  };
}

/**
 * Get field error message
 */
export function getFieldError(errors: ValidationError[], field: string): string | null {
  const error = errors.find((e) => e.field === field);
  return error?.message || null;
}
